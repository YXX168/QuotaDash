import AppKit
import Combine
import Darwin
import Foundation
import Security

// MARK: - Keychain

private enum SecretStore {
    private static let service = "com.yxx.quotadash.panel"

    static func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else {
                throw PanelError.message("无法写入 macOS 钥匙串")
            }
        } else if status != errSecSuccess {
            throw PanelError.message("无法写入 macOS 钥匙串")
        }
    }

    static func remove(_ account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PanelError.message("无法更新 macOS 钥匙串，请重新保存连接配置")
        }
    }
}

private struct ConnectionStorage {
    var readSecret: (String) -> String? = SecretStore.read
    var writeSecret: (String, String) throws -> Void = { try SecretStore.write($0, account: $1) }
    var removeSecret: (String) throws -> Void = SecretStore.remove
    var readLegacyURL: () -> String? = { UserDefaults.standard.string(forKey: "baseURL") }
    var removeLegacyURL: () -> Void = { UserDefaults.standard.removeObject(forKey: "baseURL") }

    func loadBaseURL() throws -> String {
        let saved = readSecret("baseURL")
        guard let legacy = readLegacyURL() else { return saved ?? "" }
        let value = saved ?? legacy
        // A failed migration must leave the old value available for retry.
        try writeSecret(value, "baseURL")
        removeLegacyURL()
        return value
    }

    func save(baseURL: String, key: String) throws {
        let previousURL = readSecret("baseURL")
        try writeSecret(baseURL, "baseURL")
        do {
            try writeSecret(key, "managementKey")
        } catch {
            // Avoid pairing the previous key with a new service address.
            if let previousURL { try? writeSecret(previousURL, "baseURL") }
            else { try? removeSecret("baseURL") }
            throw PanelError.message("连接配置未完整保存到钥匙串，请重新保存后重试")
        }
        removeLegacyURL()
    }
}

// MARK: - Data types

private struct QuotaWindow: Identifiable {
    let id = UUID()
    let label: String
    let remaining: Double?
    let resetAt: Date?
}

private struct WorkBuddyPackage {
    let name: String
    let remain: Double?
    let used: Double?
    let size: Double?
    let cycleStart: Date?
    let cycleEnd: Date?
}

private struct WorkBuddyCredits {
    let totalRemain: Double?
    let totalUsed: Double?
    let totalSize: Double?
    let packCount: Int?
    let fetchedAt: Date?
    let packages: [WorkBuddyPackage]

    var remainingPercentage: Double? {
        guard let totalRemain, let totalSize, totalSize > 0 else { return nil }
        let percentage = totalRemain / totalSize * 100
        return percentage.isFinite ? max(0, min(100, percentage)) : nil
    }

    init(_ object: [String: Any]) {
        packCount = asInt(object["pack_count"])
        fetchedAt = date(object["fetched_at"])
        packages = (object["packages"] as? [[String: Any]] ?? []).map {
            WorkBuddyPackage(name: string($0["name"]) ?? "积分包",
                             remain: asDouble($0["remain"]), used: asDouble($0["used"]),
                             size: asDouble($0["size"]), cycleStart: date($0["cycle_start"]),
                             cycleEnd: date($0["cycle_end"]))
        }
        let remain = asDouble(object["total_remain"])
        let used = asDouble(object["total_used"])
        let size = asDouble(object["total_size"])
        // The plugin treats an all-zero snapshot without packages as no data,
        // rather than an exhausted quota. Keep it unknown in the panel too.
        let noData = remain == 0 && used == 0 && size == 0 && packages.isEmpty && (packCount ?? 0) == 0
        totalRemain = noData ? nil : remain
        totalUsed = noData ? nil : used
        totalSize = noData ? nil : size
    }
}

private struct CredentialQuota: Identifiable {
    let id: String
    let provider: String
    let email: String
    let plan: String?
    let disabled: Bool
    let windows: [QuotaWindow]
    let resetCredits: Int?
    let error: String?
    var workBuddyCredits: WorkBuddyCredits? = nil
    var region: String? = nil
    var exhausted: Bool = false

    var minimumRemaining: Double? {
        if disabled || error != nil { return nil }
        if provider == "workbuddy" { return workBuddyCredits?.remainingPercentage }
        return windows.compactMap(\.remaining).min()
    }

    var providerLabel: String { provider == "workbuddy" ? "WorkBuddy" : provider.uppercased() }
    var displayIdentity: String { maskedIdentity(email, providerLabel: providerLabel) }
    var providerSymbol: String { provider == "workbuddy" ? "W" : provider == "codex" ? "✦" : "◇" }
    var providerColor: NSColor { provider == "workbuddy" ? .systemPurple : provider == "codex" ? .systemMint : .systemCyan }
}

private enum APIService { case management, upstream, workBuddy }

private enum PanelError: LocalizedError {
    case message(String)
    case httpStatus(Int, APIService)

    var errorDescription: String? {
        switch self {
        case let .message(text): return text
        case let .httpStatus(status, service):
            let label = service == .upstream ? "额度服务" : service == .workBuddy ? "WorkBuddy 管理接口" : "管理接口"
            let guidance: String
            switch status {
            case 401, 403:
                guidance = service == .upstream ? "请在管理端检查账号授权后重试" : "请检查管理密钥和访问权限后重试"
            case 404:
                guidance = service == .workBuddy ? "请在管理端检查 WorkBuddy 插件是否启用及路由配置" : "请检查管理地址和服务版本"
            case 429: guidance = "请求过于频繁，请稍后重试"
            case 500...599: guidance = "服务暂时不可用，请稍后重试或检查管理端状态"
            case 300...399: guidance = "请在连接配置中填写最终管理地址后重试"
            default: guidance = "请检查管理端状态后重试"
            }
            return "\(label)返回 HTTP \(status)。\(guidance)"
        }
    }
}

private func safeErrorMessage(_ error: Error) -> String {
    if let error = error as? PanelError { return error.errorDescription ?? "读取失败，请稍后重试" }
    if let error = error as? URLError {
        switch error.code {
        case .timedOut: return "连接超时，请检查网络和管理服务后重试"
        case .notConnectedToInternet, .networkConnectionLost:
            return "网络连接不可用，请检查网络后重试"
        case .cannotFindHost, .dnsLookupFailed, .cannotConnectToHost:
            return "无法连接管理服务，请检查地址和服务状态后重试"
        case .secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateUntrusted,
             .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid,
             .clientCertificateRejected, .clientCertificateRequired:
            return "安全连接验证失败，请检查管理服务的证书配置"
        case .cancelled: return "请求已取消，请重新刷新"
        default: return "网络请求失败，请检查连接配置后重试"
        }
    }
    return "读取失败，请检查连接配置和管理端状态后重试"
}

// Never follow redirects with a management key or query another origin.
private final class ManagementSessionDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

// MARK: - API client

private final class ManagementClient {
    let baseURL: URL
    let managementKey: String
    let session: URLSession

    init(baseURL: URL, managementKey: String, session: URLSession? = nil) {
        self.baseURL = baseURL
        self.managementKey = managementKey
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 35
        self.session = session ?? URLSession(configuration: configuration,
                                            delegate: ManagementSessionDelegate(), delegateQueue: nil)
    }

    deinit { session.invalidateAndCancel() }

    func fetchCredentials() async throws -> [[String: Any]] {
        let response = try await requestJSON(
            method: "GET",
            url: endpoint("credentials")
        )
        guard let files = response["files"] as? [[String: Any]] else {
            throw PanelError.message("管理接口没有返回 credentials 列表")
        }
        return files
    }

    func fetchCredential(_ file: [String: Any]) async -> CredentialQuota {
        let id = string(file["id"]) ?? string(file["name"]) ?? UUID().uuidString
        let provider = (string(file["provider"]) ?? string(file["type"]) ?? "OAuth").lowercased()
        let email = string(file["email"]) ?? string(file["account"]) ?? string(file["label"]) ?? id
        // WorkBuddy identities are opaque strings: never coerce or trim them.
        let authIndex = provider == "workbuddy"
            ? (file["auth_index"] as? String ?? file["authIndex"] as? String)
            : (string(file["auth_index"]) ?? string(file["authIndex"]))
        let disabled = asBool(file["disabled"])

        if disabled {
            return CredentialQuota(id: id, provider: provider, email: email,
                                   plan: "已禁用", disabled: true, windows: [],
                                   resetCredits: nil, error: nil)
        }

        guard let authIndex, !authIndex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return CredentialQuota(id: id, provider: provider, email: email,
                                   plan: nil, disabled: false, windows: [], resetCredits: nil,
                                   error: "认证文件缺少 auth_index")
        }

        do {
            if provider == "codex" {
                return try await fetchCodex(file: file, id: id, email: email, authIndex: authIndex)
            }
            if provider == "antigravity" {
                return try await fetchAntigravity(file: file, id: id, email: email, authIndex: authIndex)
            }
            if provider == "workbuddy" {
                return try await fetchWorkBuddy(id: id, email: email, authIndex: authIndex)
            }
            return CredentialQuota(id: id, provider: provider, email: email,
                                   plan: nil, disabled: false, windows: [], resetCredits: nil,
                                   error: "暂不支持的凭证类型")
        } catch {
            return CredentialQuota(id: id, provider: provider, email: email,
                                  plan: nil, disabled: false, windows: [], resetCredits: nil,
                                  error: safeErrorMessage(error))
        }
    }

    private func fetchWorkBuddy(id: String, email: String, authIndex: String) async throws -> CredentialQuota {
        func creditsURL(base: URL) throws -> URL {
            guard var components = URLComponents(url: base.appendingPathComponent("plugins/workbuddy/credits"),
                                                 resolvingAgainstBaseURL: false) else {
                throw PanelError.message("管理地址格式不正确，请检查连接配置")
            }
            components.queryItems = [URLQueryItem(name: "auth_index", value: authIndex)]
            // Go's query parser treats an unescaped '+' as a space.
            components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
            guard let url = components.url else { throw PanelError.message("管理地址格式不正确，请检查连接配置") }
            return url
        }

        let response: [String: Any]
        do {
            response = try await requestJSON(method: "GET", url: creditsURL(base: baseURL), service: .workBuddy)
        } catch PanelError.httpStatus(404, .workBuddy) {
            // Some hosts expose plugin routes only on v0. Retry only an actual
            // HTTP 404 from v8, retaining the origin, deployment prefix and query.
            guard baseURL.path.hasSuffix("/v8/management"),
                  var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
                throw PanelError.httpStatus(404, .workBuddy)
            }
            components.percentEncodedPath = String(components.percentEncodedPath.dropLast("/v8/management".count)) + "/v0/management"
            guard let fallback = components.url else { throw PanelError.httpStatus(404, .workBuddy) }
            response = try await requestJSON(method: "GET", url: creditsURL(base: fallback), service: .workBuddy)
        }

        guard let accounts = response["accounts"] as? [[String: Any]] else {
            throw PanelError.message("WorkBuddy 未返回账号额度，请检查管理端插件状态后重试")
        }
        let matches = accounts.filter {
            guard let index = $0["auth_index"] as? String else { return false }
            return index.utf8.elementsEqual(authIndex.utf8)
        }
        guard matches.count == 1, let account = matches.first else {
            throw PanelError.message("WorkBuddy 账号未能唯一匹配，请检查管理端凭证后重试")
        }
        let failed = hasError(response["error"]) || hasError(account["error"])
        let credits = failed ? nil : (account["credits"] as? [String: Any]).map(WorkBuddyCredits.init)
        return CredentialQuota(id: id, provider: "workbuddy",
                               email: string(account["nickname"]) ?? email,
                               plan: string(account["plan"]), disabled: false, windows: [], resetCredits: nil,
                               error: failed ? "WorkBuddy 额度读取失败，请在管理端检查账号授权后重试" : nil,
                               workBuddyCredits: credits, region: string(account["region"]),
                               exhausted: !failed && asBool(account["exhausted"]))
    }

    private func fetchCodex(file: [String: Any], id: String, email: String, authIndex: String) async throws -> CredentialQuota {
        var headers = [
            "Authorization": "Bearer $TOKEN$",
            "Content-Type": "application/json",
            "User-Agent": "codex-tui/0.149.1 (Mac OS; arm64)",
        ]
        if let idToken = file["id_token"] as? [String: Any],
           let accountID = string(idToken["chatgpt_account_id"]), !accountID.isEmpty {
            headers["Chatgpt-Account-Id"] = accountID
        }

        let usage = try await apiCall(
            authIndex: authIndex,
            upstreamURL: "https://chatgpt.com/backend-api/wham/usage",
            method: "GET",
            headers: headers
        )
        let rate = (usage["rate_limit"] as? [String: Any]) ??
            (usage["rateLimit"] as? [String: Any]) ?? [:]
        let primary = parseWindow(rate["primary_window"] ?? rate["primaryWindow"], label: "5 小时额度")
        let secondary = parseWindow(rate["secondary_window"] ?? rate["secondaryWindow"], label: "周额度")

        var resetCredits: Int?
        do {
            var resetHeaders = headers
            resetHeaders["Accept"] = "application/json"
            resetHeaders["OpenAI-Beta"] = "codex-1"
            resetHeaders["Originator"] = "Codex Desktop"
            let credits = try await apiCall(
                authIndex: authIndex,
                upstreamURL: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits",
                method: "GET",
                headers: resetHeaders
            )
            resetCredits = asInt(credits["availableCount"] ?? credits["available_count"])
        } catch {
            // A reset-credit request can be blocked independently of usage.
        }

        return CredentialQuota(
            id: id,
            provider: "codex",
            email: email,
            plan: string(usage["plan_type"] ?? usage["planType"]),
            disabled: false,
            windows: [primary, secondary].compactMap { $0 },
            resetCredits: resetCredits,
            error: nil
        )
    }

    private func fetchAntigravity(file: [String: Any], id: String, email: String, authIndex: String) async throws -> CredentialQuota {
        let project = string(file["project_id"]) ?? string(file["projectId"]) ?? "aicode-consumers"
        let payload = try await apiCall(
            authIndex: authIndex,
            upstreamURL: "https://daily-cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary",
            method: "POST",
            headers: [
                "Authorization": "Bearer $TOKEN$",
                "Content-Type": "application/json",
                "User-Agent": "antigravity/cli/1.0.13 (aidev_client; os_type=darwin; arch=arm64)",
            ],
            data: ["project": project]
        )
        let groups = payload["groups"] as? [[String: Any]] ?? []
        var windows: [QuotaWindow] = []
        for group in groups {
            let buckets = group["buckets"] as? [[String: Any]] ?? []
            for bucket in buckets {
                let label = string(bucket["displayName"]) ?? string(bucket["window"]) ?? "额度"
                let fraction = asDouble(bucket["remainingFraction"])
                windows.append(QuotaWindow(label: label, remaining: fraction.map { max(0, min(1, $0)) * 100 },
                                           resetAt: date(bucket["resetTime"])))
            }
        }
        if windows.isEmpty { throw PanelError.message("上游暂未返回 Antigravity 额度") }
        return CredentialQuota(id: id, provider: "antigravity", email: email,
                               plan: string(file["label"]), disabled: false, windows: windows,
                               resetCredits: nil, error: nil)
    }

    private func apiCall(authIndex: String, upstreamURL: String, method: String,
                         headers: [String: String], data: [String: Any]? = nil) async throws -> [String: Any] {
        var body: [String: Any] = [
            "authIndex": authIndex,
            "method": method,
            "url": upstreamURL,
            "header": headers,
        ]
        if let data {
            body["data"] = String(data: try JSONSerialization.data(withJSONObject: data), encoding: .utf8)
        }
        let response = try await requestJSON(method: "POST", url: endpoint("requests/api-call"), body: body)
        guard let status = asInt(response["status_code"]), (100...599).contains(status) else {
            throw PanelError.message("额度服务未返回有效状态，请检查管理端状态后重试")
        }
        guard (200..<300).contains(status) else {
            throw PanelError.httpStatus(status, .upstream)
        }
        if let object = response["body"] as? [String: Any] { return object }
        if let text = response["body"] as? String,
           let data = text.data(using: .utf8),
           let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            return object
        }
        throw PanelError.message("额度服务返回的数据格式不正确，请稍后重试或检查管理端状态")
    }

    private func requestJSON(method: String, url: URL, body: [String: Any]? = nil,
                             service: APIService = .management) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(managementKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PanelError.message("管理接口没有返回 HTTP 响应")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw PanelError.httpStatus(http.statusCode, service)
        }
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw PanelError.message("管理接口返回的数据格式不正确，请检查管理地址和服务状态后重试")
        }
        return object
    }

    private func endpoint(_ path: String) -> URL {
        var url = baseURL
        url.appendPathComponent(path)
        return url
    }

    private func parseWindow(_ value: Any?, label: String) -> QuotaWindow? {
        guard let value = value as? [String: Any] else { return nil }
        let used = asDouble(value["used_percent"] ?? value["usedPercent"])
        let remaining = used.map { max(0, min(100, 100 - $0)) }
        return QuotaWindow(label: label, remaining: remaining,
                           resetAt: date(value["reset_at"] ?? value["resetAt"]))
    }

}

private func normalizeManagementURL(_ value: String) throws -> URL {
    var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { throw PanelError.message("请输入 CLIProxyAPI 地址") }
    if !text.contains("://") { text = "https://\(text)" }
    guard var components = URLComponents(string: text),
          let host = components.host, !host.isEmpty,
          host.rangeOfCharacter(from: .whitespacesAndNewlines.union(.controlCharacters)) == nil else {
        throw PanelError.message("CLIProxyAPI 地址格式不正确，请填写管理服务地址")
    }
    guard let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
        throw PanelError.message("管理地址只支持 HTTP 或 HTTPS")
    }
    guard components.user == nil, components.password == nil,
          components.percentEncodedQuery == nil, components.percentEncodedFragment == nil else {
        throw PanelError.message("管理地址不能包含用户名、密码、查询参数或片段，请仅填写服务地址")
    }
    guard scheme != "http" || isLocalHTTPHost(host) else {
        throw PanelError.message("远程服务必须使用 HTTPS；HTTP 仅用于本机或局域网 IP")
    }
    if let port = components.port, !(1...65535).contains(port) {
        throw PanelError.message("管理地址的端口不正确")
    }
    components.scheme = scheme
    var path = components.percentEncodedPath.replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
    if path.hasSuffix("/management.html") {
        path = String(path.dropLast("/management.html".count))
    }
    if !path.hasSuffix("/v8/management") && !path.hasSuffix("/v0/management") {
        path += "/v8/management"
    }
    components.percentEncodedPath = path
    guard let url = components.url else { throw PanelError.message("CLIProxyAPI 地址格式不正确") }
    return url
}

private func isLocalHTTPHost(_ host: String) -> Bool {
    if host.lowercased() == "localhost" { return true }
    let literal = host.hasPrefix("[") && host.hasSuffix("]") ? String(host.dropFirst().dropLast()) : host
    var ipv4 = in_addr()
    if literal.withCString({ inet_pton(AF_INET, $0, &ipv4) }) == 1 {
        let address = UInt32(bigEndian: ipv4.s_addr)
        return address >> 24 == 127 || address >> 24 == 10 ||
            address & 0xfff00000 == 0xac100000 || address & 0xffff0000 == 0xc0a80000
    }
    var ipv6 = in6_addr()
    guard literal.withCString({ inet_pton(AF_INET6, $0, &ipv6) }) == 1 else { return false }
    let bytes = withUnsafeBytes(of: ipv6) { Array($0) }
    let loopback = bytes.dropLast().allSatisfy { $0 == 0 } && bytes.last == 1
    return loopback || bytes[0] & 0xfe == 0xfc || (bytes[0] == 0xfe && bytes[1] & 0xc0 == 0x80)
}

private func maskedIdentity(_ value: String, providerLabel: String) -> String {
    let parts = value.split(separator: "@", omittingEmptySubsequences: false)
    guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return "\(providerLabel) 账号" }
    let prefix = parts[0].count > 2 ? String(parts[0].prefix(2)) : ""
    return "\(prefix)***@\(parts[1])"
}

private func menuSegments(_ quotas: [CredentialQuota]) -> [String] {
    [("codex", "C"), ("antigravity", "A"), ("workbuddy", "W")].compactMap { provider, mark in
        let accounts = quotas.filter { $0.provider == provider }
        guard !accounts.isEmpty else { return nil }
        let active = accounts.filter { !$0.disabled }
        let remaining = active.contains { $0.minimumRemaining == nil } ? nil : active.compactMap(\.minimumRemaining).min()
        return "\(mark) \(percentageText(remaining))"
    }
}

// MARK: - Dashboard model

@MainActor
private final class DashboardModel: ObservableObject {
    @Published var quotas: [CredentialQuota] = []
    @Published var isRefreshing = false
    @Published var lastUpdated: Date?
    @Published var error: String?
    @Published var baseURL: String

    private(set) var managementKey: String
    private let storage: ConnectionStorage

    init(storage: ConnectionStorage = ConnectionStorage()) {
        self.storage = storage
        baseURL = ""
        managementKey = storage.readSecret("managementKey") ?? ""
        do { baseURL = try storage.loadBaseURL() }
        catch {
            baseURL = storage.readSecret("baseURL") ?? storage.readLegacyURL() ?? ""
            self.error = safeErrorMessage(error)
        }
    }

    var minimumRemaining: Double? {
        quotas.compactMap(\.minimumRemaining).min()
    }

    func saveConfiguration(baseURL: String, key: String) throws {
        let normalized = try normalizeManagementURL(baseURL)
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PanelError.message("请输入管理密钥")
        }
        try storage.save(baseURL: normalized.absoluteString, key: key)
        self.baseURL = normalized.absoluteString
        managementKey = key
        error = nil
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        error = nil
        Task {
            do {
                let url = try normalizeManagementURL(baseURL)
                guard !managementKey.isEmpty else { throw PanelError.message("请先配置管理密钥") }
                let client = ManagementClient(baseURL: url, managementKey: managementKey)
                let files = try await client.fetchCredentials()
                var results: [CredentialQuota] = []
                await withTaskGroup(of: CredentialQuota.self) { group in
                    for file in files { group.addTask { await client.fetchCredential(file) } }
                    for await result in group { results.append(result) }
                }
                results.sort { $0.email.localizedCaseInsensitiveCompare($1.email) == .orderedAscending }
                quotas = results
                lastUpdated = Date()
            } catch {
                self.error = safeErrorMessage(error)
                quotas = []
            }
            isRefreshing = false
        }
    }

}

// MARK: - AppKit views

private final class DashboardViewController: NSViewController {
    let model: DashboardModel
    private var changeObserver: AnyCancellable?
    private var refreshTimer: Timer?
    private var contentStack = NSStackView()
    private var settingsWindow: SettingsWindowController?

    init(model: DashboardModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() { view = NSView() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.96).cgColor
        buildShell()
        changeObserver = model.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.rebuildContent() }
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak model] _ in
            Task { @MainActor in model?.refresh() }
        }
        model.refresh()
    }

    deinit { refreshTimer?.invalidate() }

    private func buildShell() {
        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 0
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            root.topAnchor.constraint(equalTo: view.topAnchor),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let header = NSStackView()
        header.alignment = .centerY
        header.spacing = 9
        header.edgeInsets = NSEdgeInsets(top: 15, left: 17, bottom: 12, right: 17)
        let mark = NSTextField(labelWithString: "◉")
        mark.font = .systemFont(ofSize: 23, weight: .semibold)
        mark.textColor = .systemCyan
        header.addArrangedSubview(mark)
        let titles = NSStackView()
        titles.orientation = .vertical
        titles.spacing = 1
        let title = NSTextField(labelWithString: "Quota Dash")
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        let subtitle = NSTextField(labelWithString: "CLIProxyAPI额度")
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        titles.addArrangedSubview(title)
        titles.addArrangedSubview(subtitle)
        header.addArrangedSubview(titles)
        header.addArrangedSubview(NSView())
        let settings = NSButton(image: NSImage(systemSymbolName: "gearshape", accessibilityDescription: "连接配置")!, target: self, action: #selector(openSettings))
        settings.bezelStyle = .texturedRounded
        settings.isBordered = false
        settings.toolTip = "连接配置"
        header.addArrangedSubview(settings)
        let refresh = NSButton(image: NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "刷新额度")!, target: self, action: #selector(refreshNow))
        refresh.bezelStyle = .texturedRounded
        refresh.isBordered = false
        refresh.toolTip = "刷新额度"
        header.addArrangedSubview(refresh)
        root.addArrangedSubview(header)
        let headerSeparator = NSBox()
        headerSeparator.boxType = .separator
        root.addArrangedSubview(headerSeparator)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .width
        contentStack.spacing = 10
        contentStack.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        let clip = NSView()
        clip.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: clip.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: clip.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: clip.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
        ])
        scroll.documentView = clip
        root.addArrangedSubview(scroll)
        root.setHuggingPriority(.defaultLow, for: .vertical)
        let footerSeparator = NSBox()
        footerSeparator.boxType = .separator
        root.addArrangedSubview(footerSeparator)

        let footer = NSStackView()
        footer.edgeInsets = NSEdgeInsets(top: 8, left: 17, bottom: 8, right: 17)
        footer.addArrangedSubview(NSTextField(labelWithString: ""))
        footer.addArrangedSubview(NSView())
        let quit = NSButton(title: "退出", target: self, action: #selector(quitApp))
        quit.bezelStyle = .inline
        quit.isBordered = false
        quit.contentTintColor = .secondaryLabelColor
        footer.addArrangedSubview(quit)
        root.addArrangedSubview(footer)
        rebuildContent()
    }

    private func rebuildContent() {
        guard isViewLoaded else { return }
        contentStack.arrangedSubviews.forEach { contentStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        if let error = model.error, model.quotas.isEmpty {
            contentStack.addArrangedSubview(messageView(icon: "exclamationmark.triangle", text: error, actionTitle: "打开连接配置", action: #selector(openSettings)))
            return
        }
        if model.quotas.isEmpty {
            let text = model.isRefreshing ? "正在读取额度…" : "还没有额度数据"
            contentStack.addArrangedSubview(messageView(icon: model.isRefreshing ? "arrow.triangle.2.circlepath" : "gauge", text: text, actionTitle: model.isRefreshing ? nil : "刷新", action: #selector(refreshNow)))
            return
        }
        if let error = model.error { contentStack.addArrangedSubview(warningLabel(error)) }
        for quota in model.quotas { contentStack.addArrangedSubview(card(for: quota)) }
    }

    private func messageView(icon: String, text: String, actionTitle: String?, action: Selector) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 55, left: 20, bottom: 55, right: 20)
        let image = NSImageView(image: NSImage(systemSymbolName: icon, accessibilityDescription: nil)!)
        image.contentTintColor = .systemOrange
        image.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 26, weight: .medium)
        stack.addArrangedSubview(image)
        let label = NSTextField(wrappingLabelWithString: text)
        label.alignment = .center
        label.textColor = .secondaryLabelColor
        stack.addArrangedSubview(label)
        if let actionTitle {
            let button = NSButton(title: actionTitle, target: self, action: action)
            button.bezelStyle = .rounded
            stack.addArrangedSubview(button)
        }
        return stack
    }

    private func warningLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: "⚠︎  \(text)")
        label.font = .systemFont(ofSize: 11)
        label.textColor = .systemOrange
        return label
    }

    private func card(for quota: CredentialQuota) -> NSView {
        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = 11
        box.fillColor = NSColor.controlBackgroundColor.withAlphaComponent(0.72)
        box.borderColor = NSColor.separatorColor.withAlphaComponent(0.5)
        box.borderWidth = 1
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.contentView = stack
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor), stack.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            stack.topAnchor.constraint(equalTo: box.topAnchor), stack.bottomAnchor.constraint(equalTo: box.bottomAnchor),
        ])

        let heading = NSStackView()
        heading.spacing = 8
        let icon = NSTextField(labelWithString: quota.providerSymbol)
        icon.font = .systemFont(ofSize: 17, weight: .semibold)
        icon.textColor = quota.providerColor
        heading.addArrangedSubview(icon)
        let info = NSStackView()
        info.orientation = .vertical
        info.spacing = 1
        let email = NSTextField(labelWithString: quota.displayIdentity)
        email.font = .systemFont(ofSize: 12, weight: .semibold)
        email.lineBreakMode = .byTruncatingTail
        let provider = NSTextField(labelWithString: ([quota.providerLabel, quota.plan, quota.region].compactMap { $0 }).joined(separator: " · "))
        provider.font = .systemFont(ofSize: 10)
        provider.textColor = .secondaryLabelColor
        provider.lineBreakMode = .byTruncatingTail
        info.addArrangedSubview(email); info.addArrangedSubview(provider)
        heading.addArrangedSubview(info)
        heading.addArrangedSubview(NSView())
        if quota.disabled {
            let value = NSTextField(labelWithString: "已禁用")
            value.font = .systemFont(ofSize: 11, weight: .semibold)
            value.textColor = .secondaryLabelColor
            heading.addArrangedSubview(value)
        } else {
            let value = NSTextField(labelWithString: percentageText(quota.minimumRemaining))
            value.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
            value.textColor = quota.minimumRemaining.map { color(for: $0, provider: quota.provider) } ?? .secondaryLabelColor
            heading.addArrangedSubview(value)
        }
        stack.addArrangedSubview(heading)
        if quota.disabled {
            let disabledLabel = NSTextField(labelWithString: "此凭证已在 CLIProxyAPI 中禁用")
            disabledLabel.font = .systemFont(ofSize: 10)
            disabledLabel.textColor = .secondaryLabelColor
            stack.addArrangedSubview(disabledLabel)
        } else if let error = quota.error {
            stack.addArrangedSubview(warningLabel(error))
        } else if quota.provider == "workbuddy" {
            stack.addArrangedSubview(workBuddyDetails(quota))
        } else {
            for window in quota.windows {
                let line = NSStackView(); line.orientation = .vertical; line.spacing = 3
                let labels = NSStackView()
                labels.addArrangedSubview(NSTextField(labelWithString: window.label))
                labels.addArrangedSubview(NSView())
                labels.addArrangedSubview(NSTextField(labelWithString: percentageText(window.remaining)))
                for item in labels.arrangedSubviews {
                    (item as? NSTextField)?.font = .systemFont(ofSize: 10)
                }
                line.addArrangedSubview(labels)
                if let remaining = window.remaining { line.addArrangedSubview(progressBar(remaining)) }
                if let reset = window.resetAt {
                    let resetLabel = NSTextField(labelWithString: "刷新：\(reset.formatted(date: .omitted, time: .shortened))")
                    resetLabel.font = .systemFont(ofSize: 9); resetLabel.textColor = .secondaryLabelColor
                    line.addArrangedSubview(resetLabel)
                }
                stack.addArrangedSubview(line)
            }
            if let credits = quota.resetCredits {
                let creditsLabel = NSTextField(labelWithString: "可用主动重置次数：\(credits)")
                creditsLabel.font = .systemFont(ofSize: 9); creditsLabel.textColor = .secondaryLabelColor
                stack.addArrangedSubview(creditsLabel)
            }
        }
        return box
    }

    private func workBuddyDetails(_ quota: CredentialQuota) -> NSView {
        let details = NSStackView()
        details.orientation = .vertical
        details.alignment = .width
        details.spacing = 5
        let credits = quota.workBuddyCredits
        let remaining = NSTextField(labelWithString: "剩余积分：\(creditText(credits?.totalRemain))")
        remaining.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        remaining.textColor = credits?.remainingPercentage.map { color(for: $0, provider: "workbuddy") } ?? .secondaryLabelColor
        details.addArrangedSubview(remaining)
        let totals = NSTextField(labelWithString: "已用 \(creditText(credits?.totalUsed)) / 总量 \(creditText(credits?.totalSize)) · 积分包 \(credits?.packCount.map(String.init) ?? "--")")
        totals.font = .systemFont(ofSize: 10)
        totals.textColor = .secondaryLabelColor
        details.addArrangedSubview(totals)
        if let percentage = credits?.remainingPercentage { details.addArrangedSubview(progressBar(percentage)) }
        if quota.exhausted { details.addArrangedSubview(warningLabel("积分已耗尽")) }
        for package in credits?.packages ?? [] {
            let label = NSTextField(wrappingLabelWithString: "\(package.name)：剩余 \(creditText(package.remain)) / \(creditText(package.size)) · 已用 \(creditText(package.used))")
            label.font = .systemFont(ofSize: 10)
            details.addArrangedSubview(label)
            let expiry = NSTextField(labelWithString: "到期：\(package.cycleEnd.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "--")")
            expiry.font = .systemFont(ofSize: 9)
            expiry.textColor = package.cycleEnd.map { $0 <= Date() ? .systemOrange : .secondaryLabelColor } ?? .secondaryLabelColor
            expiry.toolTip = package.cycleStart.map { "周期开始：\($0.formatted(date: .abbreviated, time: .shortened))" }
            details.addArrangedSubview(expiry)
        }
        if let fetched = credits?.fetchedAt {
            let label = NSTextField(labelWithString: "额度采集：\(fetched.formatted(date: .abbreviated, time: .shortened))")
            label.font = .systemFont(ofSize: 9)
            label.textColor = .secondaryLabelColor
            details.addArrangedSubview(label)
        }
        return details
    }

    private func progressBar(_ remaining: Double) -> NSProgressIndicator {
        let progress = NSProgressIndicator()
        progress.isIndeterminate = false
        progress.controlSize = .small
        progress.style = .bar
        progress.minValue = 0
        progress.maxValue = 100
        progress.doubleValue = max(0, min(100, remaining))
        return progress
    }

    private func color(for value: Double, provider: String) -> NSColor {
        value < 25 ? .systemRed : value < 60 ? .systemOrange : provider == "workbuddy" ? .systemPurple : .systemMint
    }

    @objc private func refreshNow() { model.refresh() }
    @objc private func openSettings() {
        settingsWindow = SettingsWindowController(model: model)
        settingsWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func quitApp() { NSApp.terminate(nil) }
}

private final class SettingsWindowController: NSWindowController {
    init(model: DashboardModel) {
        let controller = SettingsViewController(model: model)
        let window = NSWindow(contentViewController: controller)
        window.title = "Quota Dash 连接配置"
        window.styleMask = [.titled, .closable]
        window.center()
        super.init(window: window)
        controller.closeWindow = { [weak self] in self?.close() }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class SettingsViewController: NSViewController {
    let model: DashboardModel
    var closeWindow: (() -> Void)?
    private let address = NSTextField()
    private let key = NSSecureTextField()
    private let errorLabel = NSTextField(wrappingLabelWithString: "")

    init(model: DashboardModel) { self.model = model; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() { view = NSView() }
    override func viewDidLoad() {
        super.viewDidLoad()
        let stack = NSStackView(); stack.orientation = .vertical; stack.spacing = 12; stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22), stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22), stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 22), stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -22)])
        let title = NSTextField(labelWithString: "连接配置"); title.font = .systemFont(ofSize: 17, weight: .semibold); stack.addArrangedSubview(title)
        let hint = NSTextField(wrappingLabelWithString: "地址和密钥只保存到本机 macOS 钥匙串。地址可以填写服务根地址，应用会自动补全 /v8/management。"); hint.font = .systemFont(ofSize: 11); hint.textColor = .secondaryLabelColor; stack.addArrangedSubview(hint)
        address.placeholderString = "CLIProxyAPI 地址"; address.stringValue = model.baseURL; address.controlSize = .large; stack.addArrangedSubview(address)
        key.placeholderString = "管理密钥"; key.stringValue = model.managementKey; key.controlSize = .large; stack.addArrangedSubview(key)
        errorLabel.font = .systemFont(ofSize: 11); errorLabel.textColor = .systemRed; errorLabel.isHidden = true; stack.addArrangedSubview(errorLabel)
        let buttons = NSStackView(); buttons.spacing = 8; buttons.addArrangedSubview(NSView())
        let cancel = NSButton(title: "取消", target: self, action: #selector(cancelAction)); cancel.bezelStyle = .rounded; buttons.addArrangedSubview(cancel)
        let save = NSButton(title: "保存并刷新", target: self, action: #selector(saveAction)); save.bezelStyle = .rounded; save.keyEquivalent = "\r"; buttons.addArrangedSubview(save)
        stack.addArrangedSubview(buttons)
    }
    @objc private func cancelAction() { closeWindow?() }
    @objc private func saveAction() {
        do { try model.saveConfiguration(baseURL: address.stringValue, key: key.stringValue); closeWindow?(); model.refresh() }
        catch { errorLabel.stringValue = safeErrorMessage(error); errorLabel.isHidden = false }
    }
}

// MARK: - AppKit menu bar host

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = DashboardModel()
    private var statusItem: NSStatusItem!
    private var widgetWindow: NSPanel!
    private var changeObserver: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggleWidget(_:))
        statusItem.button?.image = NSImage(systemSymbolName: "gauge.with.dots.needle.67percent", accessibilityDescription: "Quota Dash")
        let controller = DashboardViewController(model: model)
        widgetWindow = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 390, height: 560),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        widgetWindow.title = "Quota Dash"
        widgetWindow.titleVisibility = .hidden
        widgetWindow.titlebarAppearsTransparent = true
        widgetWindow.isFloatingPanel = true
        widgetWindow.level = .floating
        widgetWindow.hidesOnDeactivate = false
        widgetWindow.isMovableByWindowBackground = true
        widgetWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        widgetWindow.contentViewController = controller
        changeObserver = model.objectWillChange.sink { [weak self] _ in DispatchQueue.main.async { self?.updateStatus() } }
        widgetWindow.center()
        widgetWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        model.refresh()
    }

    @objc private func toggleWidget(_ sender: Any?) {
        if widgetWindow.isVisible { widgetWindow.orderOut(sender) }
        else { widgetWindow.orderFrontRegardless(); NSApp.activate(ignoringOtherApps: true) }
    }
    private func updateStatus() {
        guard let button = statusItem.button else { return }
        if model.isRefreshing { button.title = ""; button.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "正在刷新"); return }
        let segments = menuSegments(model.quotas)
        button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.67percent", accessibilityDescription: "Quota Dash")
        button.title = segments.isEmpty ? "" : " " + segments.joined(separator: " · ")
        button.toolTip = model.error ?? (segments.isEmpty ? "Quota Dash" : "Codex / Antigravity / WorkBuddy 剩余额度：" + segments.joined(separator: "，"))
    }
}

#if !PANEL_TESTS
@main
private struct QuotaDashPanelMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }
}
#endif

// MARK: - JSON helpers

private func string(_ value: Any?) -> String? {
    guard let value, !(value is NSNull), value is String || value is NSNumber else { return nil }
    let result = String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
    return result.isEmpty ? nil : result
}

private func asInt(_ value: Any?) -> Int? {
    if let number = value as? NSNumber {
        guard CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        return Int(exactly: number.doubleValue)
    }
    return Int(string(value) ?? "")
}

private func asDouble(_ value: Any?) -> Double? {
    let result: Double?
    if let number = value as? NSNumber {
        guard CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        result = number.doubleValue
    } else { result = Double(string(value) ?? "") }
    guard let result, result.isFinite else { return nil }
    return result
}

private func asBool(_ value: Any?) -> Bool {
    if let value = value as? Bool { return value }
    return string(value)?.lowercased() == "true"
}

private func date(_ value: Any?) -> Date? {
    guard let raw = string(value) else { return nil }
    if let epoch = asDouble(value) {
        let seconds = abs(epoch) > 100_000_000_000 ? epoch / 1000 : epoch
        guard abs(seconds) < 253_402_300_800 else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }
    let formatter = ISO8601DateFormatter()
    if let result = formatter.date(from: raw) { return result }
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: raw)
}

private func hasError(_ value: Any?) -> Bool {
    guard let value, !(value is NSNull) else { return false }
    if let text = value as? String { return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    if let number = value as? NSNumber { return number.boolValue }
    return true
}

private func percentageText(_ value: Double?) -> String {
    guard let value, value.isFinite else { return "--" }
    return "\(Int(max(0, min(100, value)).rounded()))%"
}

private func creditText(_ value: Double?) -> String {
    guard let value, value.isFinite else { return "--" }
    return value.formatted(.number.precision(.fractionLength(0...2)))
}
