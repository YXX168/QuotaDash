#!/bin/zsh
set -euo pipefail

# Exercise the native implementation with in-memory HTTP fixtures. No live
# requests, application launch, keychain access or saved settings changes.
ROOT="${0:A:h}"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/quotadash-panel-tests.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
cp "$ROOT/QuotaDashPanel.swift" "$TEST_DIR/PanelTests.swift"
cat >> "$TEST_DIR/PanelTests.swift" <<'SWIFT'

private struct FixtureReply {
    var status = 200
    var body = "{}"
    var error: Error? = nil
}

private final class FixtureProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var replies: [FixtureReply] = []
    private static var requests: [URLRequest] = []

    static func configure(_ replies: [FixtureReply]) {
        lock.lock(); defer { lock.unlock() }
        self.replies = replies
        requests = []
    }

    static func recordedRequests() -> [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return requests
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock()
        Self.requests.append(request)
        let reply = Self.replies.isEmpty
            ? FixtureReply(error: URLError(.badServerResponse)) : Self.replies.removeFirst()
        Self.lock.unlock()
        if let error = reply.error { client?.urlProtocol(self, didFailWithError: error); return }
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.status,
                                       httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(reply.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private enum FixtureFailure: Error { case failed(String) }

private func check(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !condition() { throw FixtureFailure.failed(message) }
}

private let accountIndex = "opaque+index &?#/你好"
private let privateText = "secret-url-and-token-must-not-appear"

private func envelope(_ accounts: [[String: Any]]) throws -> String {
    String(data: try JSONSerialization.data(withJSONObject: ["accounts": accounts]), encoding: .utf8)!
}

private func account(credits: [String: Any]? = nil) -> [String: Any] {
    var row: [String: Any] = ["auth_index": accountIndex, "nickname": "Buddy", "region": "global", "plan": "Pro"]
    if let credits { row["credits"] = credits }
    return row
}

private func runFixture(_ replies: [FixtureReply], base: String = "https://example.invalid:8443/prefix/v8/management",
                        credential: [String: Any]? = nil) async throws -> (CredentialQuota, [URLRequest]) {
    FixtureProtocol.configure(replies)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [FixtureProtocol.self]
    let session = URLSession(configuration: configuration, delegate: ManagementSessionDelegate(), delegateQueue: nil)
    let client = ManagementClient(baseURL: try normalizeManagementURL(base), managementKey: "fixture-key", session: session)
    let quota = await client.fetchCredential(credential ?? ["id": "credential-id", "provider": "workbuddy",
                                                          "email": "fallback@example.invalid", "auth_index": accountIndex])
    return (quota, FixtureProtocol.recordedRequests())
}

@main
private enum PanelFixtureTests {
    static func main() async throws {
        try testConnectionStorage()
        try testURLsAndErrors()
        try testHTTPPolicyAndIdentity()
        try testNumbersAndDates()
        try await testCreditsAndRouting()
        try await testUnknownAndIdentity()
        try await testFailureRoutes()
        try await testExistingProviders()
        print("Native panel fixtures passed: secure storage, credits, identity, unknown quotas, routing, errors and existing providers.")
    }

    static func testConnectionStorage() throws {
        var secrets: [String: String] = [:]
        var legacy: String? = "https://legacy.example.invalid/v8/management"
        var writes: [String] = []
        var failingAccount: String? = nil
        let storage = ConnectionStorage(readSecret: { secrets[$0] }, writeSecret: { value, name in
            writes.append(name)
            if name == failingAccount { throw FixtureFailure.failed("simulated keychain write failure") }
            secrets[name] = value
        }, removeSecret: { secrets.removeValue(forKey: $0) }, readLegacyURL: { legacy }, removeLegacyURL: { legacy = nil })
        failingAccount = "baseURL"
        do { _ = try storage.loadBaseURL(); throw FixtureFailure.failed("failed migration succeeded") }
        catch is FixtureFailure {
            try check(legacy != nil && secrets["baseURL"] == nil, "legacy deleted before keychain write")
        }
        failingAccount = nil
        let migrated = try storage.loadBaseURL()
        try check(migrated == "https://legacy.example.invalid/v8/management" && secrets["baseURL"] == migrated && legacy == nil, "legacy migration")
        legacy = "https://stale.example.invalid/v8/management"
        try check(try storage.loadBaseURL() == migrated && secrets["baseURL"] == migrated && legacy == nil, "new keychain address overwritten by legacy")
        writes = []
        try check(try storage.loadBaseURL() == migrated && writes.isEmpty, "migration repeated without legacy")
        try storage.save(baseURL: "https://new.example.invalid/v8/management", key: "fictional-new-key")
        try check(secrets["baseURL"] == "https://new.example.invalid/v8/management" && secrets["managementKey"] == "fictional-new-key", "connection saved outside keychain")
        let previous = secrets["baseURL"]
        failingAccount = "managementKey"
        do { try storage.save(baseURL: "https://failed.example.invalid/v8/management", key: "fictional-failed-key"); throw FixtureFailure.failed("partial save succeeded") }
        catch is PanelError {}
        try check(secrets["baseURL"] == previous && secrets["managementKey"] == "fictional-new-key", "failed key write left mismatched address")
        secrets = [:]
        do { try storage.save(baseURL: "https://new.example.invalid/v8/management", key: "fictional-new-key"); throw FixtureFailure.failed("partial initial save succeeded") }
        catch is PanelError {}
        try check(secrets.isEmpty, "failed initial save left an address behind")
    }

    static func testURLsAndErrors() throws {
        for (input, expected) in [
            (" example.invalid ", "https://example.invalid/v8/management"),
            ("localhost:8317/prefix/", "https://localhost:8317/prefix/v8/management"),
            ("http://127.0.0.1:8317/v0/management/", "http://127.0.0.1:8317/v0/management"),
            ("HTTPS://example.invalid/prefix/v8/management/", "https://example.invalid/prefix/v8/management"),
            ("https://example.invalid/management.html", "https://example.invalid/v8/management"),
            ("https://example.invalid/prefix/management.html/", "https://example.invalid/prefix/v8/management"),
            ("https://example.invalid/prefix/v0/management/management.html", "https://example.invalid/prefix/v0/management"),
            ("https://example.invalid/prefix%2Fname/v8/management", "https://example.invalid/prefix%2Fname/v8/management")
        ] {
            let normalized = try normalizeManagementURL(input)
            try check(normalized.absoluteString == expected, "URL normalization")
        }
        for input in ["", "https:///", "https://user:password@example.invalid", "https://@example.invalid",
                      "https://example.invalid?key=secret", "https://example.invalid?", "https://example.invalid#secret",
                      "https://example.invalid#", "ftp://example.invalid", "file:///tmp/service", "ws://example.invalid",
                      "https://example.invalid:0", "https://example.invalid:65536", "https://bad host.invalid"] {
            do { _ = try normalizeManagementURL(input); throw FixtureFailure.failed("unsafe URL accepted") }
            catch is PanelError {}
        }
        let errors: [Error] = [NSError(domain: "private", code: 1, userInfo: [NSLocalizedDescriptionKey: privateText]),
                      URLError(.timedOut, userInfo: [NSLocalizedDescriptionKey: privateText]),
                      URLError(.cannotFindHost, userInfo: [NSURLErrorFailingURLErrorKey: URL(string: "https://example.invalid")!]),
                      URLError(.serverCertificateUntrusted), URLError(.cancelled)]
        for error in errors {
            try check(!safeErrorMessage(error).contains(privateText), "error leaks details")
        }
        try check(safeErrorMessage(PanelError.httpStatus(401, .management)).contains("401"), "safe status lost")
        try check(safeErrorMessage(PanelError.httpStatus(404, .workBuddy)).contains("插件"), "missing plugin guidance")
        // Redirects cannot send the management key to another origin.
        let delegate = ManagementSessionDelegate()
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let task = session.dataTask(with: URL(string: "https://example.invalid")!)
        let response = HTTPURLResponse(url: task.originalRequest!.url!, statusCode: 302, httpVersion: nil, headerFields: nil)!
        var rejected = false
        delegate.urlSession(session, task: task, willPerformHTTPRedirection: response,
                            newRequest: URLRequest(url: URL(string: "https://other.invalid")!)) { rejected = $0 == nil }
        try check(rejected, "redirect was allowed")
    }

    static func testNumbersAndDates() throws {
        for value: Any in [NSNull(), true, false, "NaN", "inf", Double.infinity, ["bad": 1]] {
            try check(asDouble(value) == nil, "invalid quota becomes a number")
        }
        try check(asDouble("12.5") == 12.5 && asInt(true) == nil && asInt(2.5) == nil, "number decoding")
        try check(percentageText(nil) == "--" && creditText(nil) == "--", "unknown presentation")
        try check(percentageText(0) == "0%" && creditText(0) == "0", "known zero presentation")
        try check(date("2026-10-03T12:30:00.123Z") != nil && date("2026-10-03T12:30:00+08:00") != nil, "RFC3339 dates")
        try check(date(1_800_000_000)?.timeIntervalSince1970 == 1_800_000_000, "epoch dates")
        try check(date("not a date") == nil, "invalid expiry")
        let noData = WorkBuddyCredits(["total_remain": 0, "total_used": 0, "total_size": 0, "pack_count": 0, "packages": []])
        try check(noData.totalRemain == nil && noData.remainingPercentage == nil && creditText(noData.totalRemain) == "--", "empty plugin snapshot displayed as zero")
    }

    static func testHTTPPolicyAndIdentity() throws {
        for host in ["localhost", "LOCALHOST", "127.0.0.1", "127.255.255.255", "10.0.0.0", "10.255.255.255",
                     "172.16.0.0", "172.31.255.255", "192.168.0.0", "192.168.255.255", "[::1]",
                     "[fc00::1]", "[fdff:ffff::1]", "[fe80::1]", "[febf:ffff::1]"] {
            let normalized = try normalizeManagementURL("http://\(host):8317/prefix/management.html")
            try check(normalized.scheme == "http" && normalized.path == "/prefix/v8/management", "local HTTP policy")
        }
        for host in ["example.invalid", "localhost.example.invalid", "127.0.0.1.example.invalid", "0.0.0.0",
                     "126.255.255.255", "128.0.0.0", "9.255.255.255", "11.0.0.0", "172.15.255.255",
                     "172.32.0.0", "192.167.255.255", "192.169.0.0", "203.0.113.1", "127.1",
                     "10.256.0.1", "[::]", "[2001:db8::1]", "[fbff::1]", "[fe00::1]", "[fe7f::1]",
                     "[fec0::1]", "[::ffff:127.0.0.1]", "[::ffff:10.0.0.1]"] {
            do {
                _ = try normalizeManagementURL("http://\(host):8317")
                throw FixtureFailure.failed("remote HTTP accepted")
            } catch let error as PanelError {
                try check(safeErrorMessage(error) == "远程服务必须使用 HTTPS；HTTP 仅用于本机或局域网 IP", "HTTP guidance")
            }
        }
        try check(!isLocalHTTPHost("fc00:not-an-ip") && !isLocalHTTPHost("fe80::1::2"), "invalid IPv6 accepted")
        let https = try normalizeManagementURL("https://example.invalid/prefix/management.html")
        try check(https.scheme == "https", "remote HTTPS rejected")
        try check(maskedIdentity("fictional@example.invalid", providerLabel: "WorkBuddy") == "fi***@example.invalid", "email local-part mask")
        try check(maskedIdentity("a@example.invalid", providerLabel: "CODEX") == "***@example.invalid", "short email mask")
        try check(maskedIdentity("Buddy", providerLabel: "WorkBuddy") == "WorkBuddy 账号", "generic account identity")
        try check(maskedIdentity("first@example.invalid second@example.invalid", providerLabel: "WorkBuddy") == "WorkBuddy 账号", "multiple emails leaked")
    }

    static func testCreditsAndRouting() async throws {
        let totals: [String: Any] = ["total_remain": 75, "total_used": 25, "total_size": 100, "pack_count": 1,
            "fetched_at": "2026-10-03T01:02:03.456Z", "packages": [["name": "Bonus Pack", "remain": 75,
            "used": 25, "size": 100, "cycle_start": "2026-10-01T00:00:00Z", "cycle_end": "2026-10-15T00:00:00Z"]]]
        let body = try envelope([["auth_index": "different", "credits": ["total_remain": 1, "total_size": 100]], account(credits: totals)])
        let (quota, requests) = try await runFixture([FixtureReply(status: 404, body: privateText), FixtureReply(body: body)])
        try check(quota.id == "credential-id" && quota.email == "Buddy" && quota.plan == "Pro" && quota.region == "global", "account metadata")
        try check(quota.providerLabel == "WorkBuddy" && quota.providerSymbol == "W" && quota.providerColor == .systemPurple, "provider identity")
        try check(quota.displayIdentity == "WorkBuddy 账号", "native card exposes nickname")
        try check(quota.minimumRemaining == 75 && quota.workBuddyCredits?.totalUsed == 25 && quota.workBuddyCredits?.totalSize == 100, "credits totals")
        try check(quota.workBuddyCredits?.packCount == 1 && quota.workBuddyCredits?.fetchedAt != nil, "credits metadata")
        let package = quota.workBuddyCredits?.packages.first
        try check(package?.name == "Bonus Pack" && package?.remain == 75 && package?.used == 25 && package?.size == 100, "package totals")
        try check(package?.cycleStart != nil && package?.cycleEnd != nil, "package expiry")
        try check(menuSegments([quota]) == ["W 75%"], "WorkBuddy menu summary")
        try check(requests.count == 2, "v8 404 fallback count")
        for (request, version) in zip(requests, ["v8", "v0"]) {
            try check(request.httpMethod == "GET" && request.httpBody == nil, "WorkBuddy GET only")
            try check(request.url?.path == "/prefix/\(version)/management/plugins/workbuddy/credits", "fallback path")
            try check(request.url?.host == "example.invalid" && request.url?.scheme == "https" && request.url?.port == 8443, "fallback origin")
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            try check(components.queryItems?.count == 1 && components.queryItems?.first?.value == accountIndex, "auth_index query round trip")
            try check(components.percentEncodedQuery?.contains("%2B") == true, "plus must be encoded for Go")
            try check(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-key", "management auth header")
        }
        let (_, direct) = try await runFixture([FixtureReply(body: body)])
        try check(direct.count == 1 && direct.first?.url?.path.contains("/v8/") == true, "configured v8 preferred")
        let (_, v0) = try await runFixture([FixtureReply(body: body)], base: "https://example.invalid/v0/management")
        try check(v0.count == 1 && v0.first?.url?.path == "/v0/management/plugins/workbuddy/credits", "explicit v0")
        let (_, encoded) = try await runFixture([FixtureReply(status: 404), FixtureReply(body: body)],
                                                base: "https://example.invalid/prefix%2Fname/v8/management")
        try check(encoded.last?.url?.absoluteString.contains("/prefix%2Fname/v0/management/") == true, "encoded prefix preserved")
    }

    static func testUnknownAndIdentity() async throws {
        for credits: [String: Any]? in [nil, [:], ["total_remain": NSNull(), "total_size": 100],
                                        ["total_remain": true, "total_size": 100], ["total_remain": 10, "total_size": 0],
                                        ["total_remain": 10], ["total_remain": "NaN", "total_size": 100]] {
            let (quota, _) = try await runFixture([FixtureReply(body: try envelope([account(credits: credits)]))])
            try check(quota.minimumRemaining == nil && menuSegments([quota]) == ["W --"], "unknown quota treated as zero")
        }
        var zero = account(credits: ["total_remain": 0, "total_used": 100, "total_size": 100])
        zero["exhausted"] = true
        let (empty, _) = try await runFixture([FixtureReply(body: try envelope([zero]))])
        try check(empty.minimumRemaining == 0 && empty.exhausted && menuSegments([empty]) == ["W 0%"], "known exhausted quota")
        for rows in [[], [["auth_index": "different"]], [["auth_index": " " + accountIndex]],
                     [["auth_index": accountIndex.uppercased()]], [["auth_index": 12]], [account(), account()]] {
            let (quota, requests) = try await runFixture([FixtureReply(body: try envelope(rows))])
            try check(quota.error != nil && quota.minimumRemaining == nil && requests.count == 1, "identity must match uniquely and exactly")
        }
        let (numeric, noRequest) = try await runFixture([], credential: ["provider": "workbuddy", "auth_index": 12])
        try check(numeric.error != nil && noRequest.isEmpty, "numeric auth_index accepted")
        let (unicode, _) = try await runFixture([FixtureReply(body: try envelope([["auth_index": "e\u{301}", "credits": ["total_remain": 5, "total_size": 10]]]))],
                                                credential: ["provider": "workbuddy", "auth_index": "\u{e9}"])
        try check(unicode.error != nil && unicode.minimumRemaining == nil, "opaque auth_index compared after Unicode normalization")
        let (disabled, skipped) = try await runFixture([], credential: ["provider": "workbuddy", "disabled": true, "auth_index": accountIndex])
        try check(disabled.disabled && skipped.isEmpty && menuSegments([disabled]) == ["W --"], "disabled credential queried")
        var errorRow = account(credits: ["total_remain": 80, "total_size": 100])
        errorRow["error"] = privateText
        let (failed, _) = try await runFixture([FixtureReply(body: try envelope([errorRow]))])
        try check(failed.workBuddyCredits == nil && failed.minimumRemaining == nil && !failed.error!.contains(privateText), "plugin raw error leaked")
        try check(menuSegments([empty, failed]) == ["W --"], "partial unknown summary")
    }

    static func testFailureRoutes() async throws {
        for status in [301, 401, 403, 429, 500, 503] {
            let (quota, requests) = try await runFixture([FixtureReply(status: status, body: privateText)])
            try check(requests.count == 1 && quota.error?.contains("HTTP \(status)") == true, "non-404 fallback or missing status")
            try check(!quota.error!.contains(privateText) && quota.minimumRemaining == nil, "unsafe HTTP error")
        }
        let (v0, v0Requests) = try await runFixture([FixtureReply(status: 404, body: privateText)], base: "https://example.invalid/prefix/v0/management")
        try check(v0Requests.count == 1 && v0.error?.contains("404") == true, "explicit v0 retried")
        let (twice, twiceRequests) = try await runFixture([FixtureReply(status: 404), FixtureReply(status: 404)])
        try check(twiceRequests.count == 2 && twice.error?.contains("404") == true, "fallback loop")
        for reply in [FixtureReply(body: privateText), FixtureReply(body: "{\"error\":\"\(privateText)\"}"),
                      FixtureReply(error: URLError(.timedOut, userInfo: [NSLocalizedDescriptionKey: privateText]))] {
            let (quota, requests) = try await runFixture([reply])
            try check(requests.count == 1 && quota.error != nil && !quota.error!.contains(privateText), "non-HTTP failure fallback or raw error")
        }
    }

    static func testExistingProviders() async throws {
        let codexFile: [String: Any] = ["provider": "codex", "auth_index": "codex-id"]
        let (codex, requests) = try await runFixture([
            FixtureReply(body: "{\"status_code\":200,\"body\":{\"plan_type\":\"plus\",\"rate_limit\":{\"primary_window\":{\"used_percent\":30,\"reset_at\":1800000000}}}}"),
            FixtureReply(body: "{\"status_code\":200,\"body\":{\"available_count\":2}}")], credential: codexFile)
        try check(codex.minimumRemaining == 70 && codex.resetCredits == 2 && codex.windows.first?.resetAt != nil, "Codex regression")
        try check(requests.count == 2 && requests.allSatisfy { $0.url?.path == "/prefix/v8/management/requests/api-call" }, "existing proxy route")
        let (antigravity, _) = try await runFixture([FixtureReply(body: "{\"status_code\":200,\"body\":{\"groups\":[{\"buckets\":[{\"displayName\":\"Quota\",\"remainingFraction\":0.8}]}]}}")],
                                                   credential: ["provider": "antigravity", "auth_index": "a-id"])
        try check(antigravity.minimumRemaining == 80 && menuSegments([codex, antigravity]) == ["C 70%", "A 80%"], "Antigravity regression")
        let (unsafe, _) = try await runFixture([FixtureReply(body: "{\"status_code\":502,\"body\":\"\(privateText)\"}")], credential: codexFile)
        try check(unsafe.error?.contains("502") == true && !unsafe.error!.contains(privateText), "upstream body leaked")
    }
}
SWIFT
swiftc -D PANEL_TESTS -parse-as-library "$TEST_DIR/PanelTests.swift" \
  -o "$TEST_DIR/PanelTests" -framework AppKit -framework Foundation \
  -framework Security -framework Combine
"$TEST_DIR/PanelTests"
