import AppKit
import Combine
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
}

// MARK: - Data types

private struct QuotaWindow: Identifiable {
    let id = UUID()
    let label: String
    let remaining: Double?
    let resetAt: Date?
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

    var minimumRemaining: Double? {
        windows.compactMap(\.remaining).min()
    }
}

private enum PanelError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        if case let .message(text) = self { return text }
        return nil
    }
}

// MARK: - API client

private final class ManagementClient {
    let baseURL: URL
    let managementKey: String
    let session: URLSession

    init(baseURL: URL, managementKey: String) {
        self.baseURL = baseURL
        self.managementKey = managementKey
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 35
        session = URLSession(configuration: configuration)
    }

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
        let authIndex = string(file["auth_index"]) ?? string(file["authIndex"])
        let disabled = asBool(file["disabled"])

        if disabled {
            return CredentialQuota(id: id, provider: provider, email: email,
                                   plan: "已禁用", disabled: true, windows: [],
                                   resetCredits: nil, error: nil)
        }

        guard let authIndex, !authIndex.isEmpty else {
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
            return CredentialQuota(id: id, provider: provider, email: email,
                                   plan: nil, disabled: false, windows: [], resetCredits: nil,
                                   error: "暂不支持的凭证类型")
        } catch {
            return CredentialQuota(id: id, provider: provider, email: email,
                                  plan: nil, disabled: false, windows: [], resetCredits: nil,
                                  error: friendly(error))
        }
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
                windows.append(QuotaWindow(label: label, remaining: fraction.map { $0 * 100 },
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
        let status = asInt(response["status_code"]) ?? 0
        guard (200..<300).contains(status) else {
            throw PanelError.message("上游接口返回 HTTP \(status)")
        }
        if let object = response["body"] as? [String: Any] { return object }
        if let text = response["body"] as? String,
           let data = text.data(using: .utf8),
           let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return object
        }
        throw PanelError.message("上游接口返回了无效 JSON")
    }

    private func requestJSON(method: String, url: URL, body: [String: Any]? = nil) async throws -> [String: Any] {
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
            throw PanelError.message("管理接口返回 HTTP \(http.statusCode)")
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PanelError.message("管理接口返回了无效 JSON")
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

    private func friendly(_ error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription { return description }
        return error.localizedDescription
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

    init() {
        baseURL = UserDefaults.standard.string(forKey: "baseURL") ?? ""
        managementKey = SecretStore.read("managementKey") ?? ""
    }

    var minimumRemaining: Double? {
        quotas.compactMap(\.minimumRemaining).min()
    }

    func saveConfiguration(baseURL: String, key: String) throws {
        let normalized = try normalizeURL(baseURL)
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PanelError.message("请输入管理密钥")
        }
        try SecretStore.write(key, account: "managementKey")
        UserDefaults.standard.set(normalized.absoluteString, forKey: "baseURL")
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
                let url = try normalizeURL(baseURL)
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
                self.error = friendly(error)
            }
            isRefreshing = false
        }
    }

    private func normalizeURL(_ value: String) throws -> URL {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw PanelError.message("请输入 CLIProxyAPI 地址") }
        if !text.contains("://") { text = "https://\(text)" }
        guard var components = URLComponents(string: text), components.host != nil else {
            throw PanelError.message("CLIProxyAPI 地址格式不正确")
        }
        var path = components.path.replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
        if !path.hasSuffix("/v8/management") && !path.hasSuffix("/v0/management") {
            path += "/v8/management"
        }
        components.path = path
        components.query = nil
        components.fragment = nil
        guard let url = components.url else { throw PanelError.message("CLIProxyAPI 地址格式不正确") }
        return url
    }

    private func friendly(_ error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription { return description }
        return error.localizedDescription
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
        let icon = NSTextField(labelWithString: quota.provider == "codex" ? "✦" : "◇")
        icon.font = .systemFont(ofSize: 17, weight: .semibold)
        icon.textColor = quota.provider == "codex" ? .systemMint : .systemCyan
        heading.addArrangedSubview(icon)
        let info = NSStackView()
        info.orientation = .vertical
        info.spacing = 1
        let email = NSTextField(labelWithString: quota.email)
        email.font = .systemFont(ofSize: 12, weight: .semibold)
        email.lineBreakMode = .byTruncatingTail
        let provider = NSTextField(labelWithString: quota.provider.uppercased() + (quota.plan.map { " · \($0)" } ?? ""))
        provider.font = .systemFont(ofSize: 10)
        provider.textColor = .secondaryLabelColor
        info.addArrangedSubview(email); info.addArrangedSubview(provider)
        heading.addArrangedSubview(info)
        heading.addArrangedSubview(NSView())
        if quota.disabled {
            let value = NSTextField(labelWithString: "已禁用")
            value.font = .systemFont(ofSize: 11, weight: .semibold)
            value.textColor = .secondaryLabelColor
            heading.addArrangedSubview(value)
        } else if let minimum = quota.minimumRemaining {
            let value = NSTextField(labelWithString: "\(Int(minimum.rounded()))%")
            value.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
            value.textColor = color(for: minimum)
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
        } else {
            for window in quota.windows {
                let line = NSStackView(); line.orientation = .vertical; line.spacing = 3
                let labels = NSStackView()
                labels.addArrangedSubview(NSTextField(labelWithString: window.label))
                labels.addArrangedSubview(NSView())
                labels.addArrangedSubview(NSTextField(labelWithString: window.remaining.map { "\(Int($0.rounded()))%" } ?? "--"))
                for item in labels.arrangedSubviews {
                    (item as? NSTextField)?.font = .systemFont(ofSize: 10)
                }
                let progress = NSProgressIndicator(); progress.isIndeterminate = false; progress.controlSize = .small; progress.style = .bar
                progress.doubleValue = max(0, min(100, window.remaining ?? 0))
                progress.minValue = 0; progress.maxValue = 100
                line.addArrangedSubview(labels); line.addArrangedSubview(progress)
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

    private func color(for value: Double) -> NSColor { value < 25 ? .systemRed : value < 60 ? .systemOrange : .systemMint }

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
        let hint = NSTextField(wrappingLabelWithString: "密钥只保存到本机 macOS 钥匙串。地址可以填写服务根地址，应用会自动补全 /v8/management。"); hint.font = .systemFont(ofSize: 11); hint.textColor = .secondaryLabelColor; stack.addArrangedSubview(hint)
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
        catch { errorLabel.stringValue = error.localizedDescription; errorLabel.isHidden = false }
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
        let codex = model.quotas.filter { $0.provider == "codex" }.compactMap(\.minimumRemaining).min()
        let antigravity = model.quotas.filter { $0.provider == "antigravity" }.compactMap(\.minimumRemaining).min()
        var segments: [String] = []
        if let codex { segments.append("C \(Int(codex.rounded()))%") }
        if let antigravity { segments.append("A \(Int(antigravity.rounded()))%") }
        button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.67percent", accessibilityDescription: "Quota Dash")
        button.title = segments.isEmpty ? "" : " " + segments.joined(separator: " · ")
        button.toolTip = segments.isEmpty ? "Quota Dash" : "Codex / Antigravity 剩余额度：" + segments.joined(separator: "，")
    }
}

@main
private struct QuotaDashPanelMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }
}

// MARK: - JSON helpers

private func string(_ value: Any?) -> String? {
    guard let value else { return nil }
    let result = String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
    return result.isEmpty ? nil : result
}

private func asInt(_ value: Any?) -> Int? {
    if let number = value as? NSNumber { return number.intValue }
    return Int(string(value) ?? "")
}

private func asDouble(_ value: Any?) -> Double? {
    if let number = value as? NSNumber { return number.doubleValue }
    return Double(string(value) ?? "")
}

private func asBool(_ value: Any?) -> Bool {
    if let value = value as? Bool { return value }
    return string(value)?.lowercased() == "true"
}

private func date(_ value: Any?) -> Date? {
    guard let raw = string(value) else { return nil }
    let formatter = ISO8601DateFormatter()
    return formatter.date(from: raw)
}
