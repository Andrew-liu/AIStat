import Foundation

final class CodexUsageReader {
    nonisolated func readCachedSummary() -> CodexUsageSummary? {
        let windows = readCachedCodexQuota() ?? readLatestAnyCodexQuotaFromLogs()
        guard !windows.isEmpty else { return nil }

        var summary = CodexUsageSummary()
        summary.updatedAt = Date()
        summary.isInstalled = codexExecutable != nil
        summary.isLoggedIn = codexAccessToken() != nil || codexExecutable != nil
        summary.quotaWindows = windows
        summary.source = "Cached quota"
        summary.fiveHour = windows.first { $0.name == "5h" }
        summary.weekly = windows.first { $0.name == "Week" }
        let firstWindow = windows.first
        summary.todayUsedPercent = summary.fiveHour?.usedPercent ?? firstWindow?.usedPercent
        summary.todayUnusedPercent = summary.todayUsedPercent.map { max(0, min(100, 100 - $0)) }
        if let claudeWindows = readCachedClaudeQuota(), !claudeWindows.isEmpty {
            summary.claude = ClaudeUsageSummary(
                quotaWindows: claudeWindows,
                cost: .empty,
                isConfigured: true,
                source: "Cached quota"
            )
        }
        return summary
    }

    nonisolated func readSummary() async -> CodexUsageSummary {
        await Task.detached(priority: .utility) {
            var summary = CodexUsageSummary()
            summary.updatedAt = Date()

            let executable = self.codexExecutable
            summary.isInstalled = executable != nil
            summary.isLoggedIn = executable.map(self.isLoggedIn(codex:)) ?? false

            let codexQuota = self.readCodexQuota(codex: executable)
            summary.quotaWindows = codexQuota.windows
            summary.source = codexQuota.source
            summary.fiveHour = codexQuota.windows.first { $0.name == "5h" }
            summary.weekly = codexQuota.windows.first { $0.name == "Week" }

            let firstWindow = codexQuota.windows.first
            let todayUsed = self.readTodayUsedPercent() ?? summary.fiveHour?.usedPercent ?? firstWindow?.usedPercent
            summary.todayUsedPercent = todayUsed
            summary.todayUnusedPercent = todayUsed.map { max(0, min(100, 100 - $0)) }
            summary.cost = self.readCostSummary()
            summary.claude = self.readClaudeUsageSummary()
            return summary
        }.value
    }

    private nonisolated var codexExecutable: String? {
        let fileManager = FileManager.default
        let candidates = [
            "/Applications/Codex.app/Contents/Resources/codex",
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/codex").path,
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ]
        return candidates.first { fileManager.isExecutableFile(atPath: $0) }
    }

    private nonisolated var claudeExecutable: String? {
        let fileManager = FileManager.default
        let candidates = [
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/claude").path,
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude"
        ]
        return candidates.first { fileManager.isExecutableFile(atPath: $0) }
    }

    private nonisolated func readCodexQuota(codex: String?) -> (windows: [RateLimitWindow], source: String) {
        if let codex {
            refreshCodexAuthIfStale(codex: codex)
        }
        if let windows = readCodexOAuthWindows(), !windows.isEmpty {
            saveCachedCodexQuota(windows)
            return (windows, "Codex OAuth API")
        }
        if let codex, let windows = readLiveLimits(codex: codex), !windows.isEmpty {
            saveCachedCodexQuota(windows)
            return (windows, "Codex CLI RPC")
        }
        let logged = readLatestLoggedLimits()
        if !logged.isEmpty {
            saveCachedCodexQuota(logged)
            return (logged, "Local session logs")
        }
        let robustLogged = readLatestAnyCodexQuotaFromLogs()
        if !robustLogged.isEmpty {
            saveCachedCodexQuota(robustLogged)
            return (robustLogged, "Local session logs")
        }
        if let cached = readCachedCodexQuota(), !cached.isEmpty {
            return (cached, "Cached quota")
        }
        return ([], "No quota detected")
    }

    private nonisolated func readCachedCodexQuota() -> [RateLimitWindow]? {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/AIStat/quota/codex-v1.json")
        guard let data = try? Data(contentsOf: url),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        let windows = rows.compactMap { row -> RateLimitWindow? in
            guard let id = row["id"] as? String,
                  let name = row["name"] as? String,
                  let used = doubleOptional(row["usedPercent"]) else { return nil }
            let reset = dateFromAny(row["resetsAt"])
            let duration = intOptional(row["durationMinutes"])
            return RateLimitWindow(id: id, name: name, usedPercent: used, resetsAt: reset, durationMinutes: duration)
        }
        return windows.isEmpty ? nil : windows
    }

    private nonisolated func saveCachedCodexQuota(_ windows: [RateLimitWindow]) {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/AIStat/quota/codex-v1.json")
        let rows: [[String: Any]] = windows.map { window in
            var row: [String: Any] = [
                "id": window.id,
                "name": window.name,
                "usedPercent": window.usedPercent
            ]
            if let resetsAt = window.resetsAt { row["resetsAt"] = resetsAt.timeIntervalSince1970 }
            if let duration = window.durationMinutes { row["durationMinutes"] = duration }
            return row
        }
        guard let data = try? JSONSerialization.data(withJSONObject: rows) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: [.atomic])
    }

    private nonisolated func isLoggedIn(codex: String) -> Bool {
        guard let result = runProcess(codex, arguments: ["login", "status"], timeout: 4) else { return false }
        return result.exitCode == 0 && result.output.localizedCaseInsensitiveContains("logged in")
    }

    private nonisolated func readCodexOAuthWindows() -> [RateLimitWindow]? {
        guard let token = codexAccessToken() else { return nil }
        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let data = performRequest(request, timeout: 8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return parseCodexOAuthWindows(from: object)
    }

    private nonisolated func codexAccessToken() -> String? {
        guard let object = codexAuthObject() else { return nil }
        if let tokens = object["tokens"] as? [String: Any], let token = tokens["access_token"] as? String, !token.isEmpty {
            return token
        }
        return object["access_token"] as? String
    }

    private nonisolated func refreshCodexAuthIfStale(codex: String) {
        guard let object = codexAuthObject(), let lastRefresh = parseDate(object["last_refresh"]), Date().timeIntervalSince(lastRefresh) > 8 * 86_400 else {
            return
        }
        _ = readLiveLimits(codex: codex)
    }

    private nonisolated func codexAuthObject() -> [String: Any]? {
        let home = ProcessInfo.processInfo.environment["CODEX_HOME"].map(URL.init(fileURLWithPath:))
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
        let auth = home.appendingPathComponent("auth.json")
        guard let data = try? Data(contentsOf: auth) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private nonisolated func parseCodexOAuthWindows(from object: [String: Any]) -> [RateLimitWindow] {
        let rateLimit = (object["rate_limit"] as? [String: Any])
            ?? (object["rateLimit"] as? [String: Any])
            ?? (object["rateLimits"] as? [String: Any])
            ?? object
        var windows: [RateLimitWindow] = []
        if let window = parseFlexibleWindow(rateLimit["primary_window"] ?? rateLimit["primaryWindow"] ?? rateLimit["primary"], id: "codex-primary", fallbackName: "5h") {
            windows.append(window)
        }
        if let window = parseFlexibleWindow(rateLimit["secondary_window"] ?? rateLimit["secondaryWindow"] ?? rateLimit["secondary"], id: "codex-secondary", fallbackName: "Week") {
            windows.append(window)
        }
        if let additional = object["additional_rate_limits"] as? [[String: Any]] ?? object["additionalRateLimits"] as? [[String: Any]] {
            for (index, item) in additional.enumerated() {
                let name = (item["name"] as? String) ?? (item["title"] as? String) ?? (item["limit_name"] as? String) ?? "Extra \(index + 1)"
                if let window = parseFlexibleWindow(item, id: "codex-extra-\(index)", fallbackName: name) {
                    windows.append(window)
                }
            }
        }
        return dedupeWindows(windows)
    }

    private nonisolated func readLiveLimits(codex: String) -> [RateLimitWindow]? {
        guard let result = runProcess("/bin/zsh", arguments: ["-c", appServerCommand(codex: codex)], timeout: 8), result.exitCode == 0 else { return nil }
        return parseLiveLimits(from: Data(result.output.utf8))
    }

    private nonisolated func appServerCommand(codex: String) -> String {
        let initialize = #"{"id":1,"method":"initialize","params":{"clientInfo":{"name":"AIStat","version":"1.0"}}}"#
        let initialized = #"{"method":"initialized"}"#
        let account = #"{"id":2,"method":"account/read"}"#
        let limits = #"{"id":3,"method":"account/rateLimits/read"}"#
        let quotedCodex = codex.replacingOccurrences(of: "'", with: "'\\''")
        return "(printf '%s\\n' '\(initialize)'; sleep 0.4; printf '%s\\n' '\(initialized)' '\(account)' '\(limits)'; sleep 3) | '\(quotedCodex)' -s read-only -a untrusted app-server"
    }

    private nonisolated func parseLiveLimits(from data: Data) -> [RateLimitWindow]? {
        for line in data.split(separator: 0x0A) {
            guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  (object["id"] as? NSNumber)?.intValue == 3,
                  let result = object["result"] as? [String: Any],
                  let limits = result["rateLimits"] as? [String: Any] else { continue }
            var windows: [RateLimitWindow] = []
            if let primary = parseFlexibleWindow(limits["primary"], id: "codex-primary", fallbackName: "5h") { windows.append(primary) }
            if let secondary = parseFlexibleWindow(limits["secondary"], id: "codex-secondary", fallbackName: "Week") { windows.append(secondary) }
            if let byLimit = result["rateLimitsByLimitId"] as? [String: Any] {
                for (limitID, value) in byLimit where limitID != "codex" {
                    if let dict = value as? [String: Any], let primary = parseFlexibleWindow(dict["primary"], id: "codex-\(limitID)", fallbackName: dict["limitName"] as? String ?? limitID) {
                        windows.append(primary)
                    }
                }
            }
            return dedupeWindows(windows)
        }
        return nil
    }

    private nonisolated func readCodexStatusWindows(codex: String) -> [RateLimitWindow]? {
        let quotedCodex = codex.replacingOccurrences(of: "'", with: "'\\''")
        let command = "printf '/status\\n' | '\(quotedCodex)' 2>/dev/null"
        guard let result = runPtyShellCommand(command, timeout: 8), result.exitCode == 0 else { return nil }
        return parseStatusWindows(result.output, provider: "codex")
    }

    private nonisolated func readLatestLoggedLimits() -> [RateLimitWindow] {
        let fileManager = FileManager.default
        let root = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".codex/sessions")
        guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }

        var latestDate = Date.distantPast
        var latest: [RateLimitWindow] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard let data = try? Data(contentsOf: url) else { continue }
            for line in data.split(separator: 0x0A) {
                guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                      let timestamp = parseDate(object["timestamp"]),
                      timestamp > latestDate,
                      let limits = extractLoggedLimits(from: object),
                      !limits.isEmpty else { continue }
                latestDate = timestamp
                latest = limits
            }
        }
        return latest
    }

    private nonisolated func readLatestAnyCodexQuotaFromLogs() -> [RateLimitWindow] {
        let fileManager = FileManager.default
        let home = ProcessInfo.processInfo.environment["CODEX_HOME"].map(URL.init(fileURLWithPath:))
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
        let roots = [home.appendingPathComponent("sessions"), home.appendingPathComponent("archived_sessions")]
        var files: [(url: URL, modified: Date)] = []
        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { continue }
            for case let url as URL in enumerator where url.pathExtension == "jsonl" {
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                files.append((url, modified))
            }
        }

        for file in files.sorted(by: { $0.modified > $1.modified }).prefix(40) {
            guard let text = try? String(contentsOf: file.url, encoding: .utf8) else { continue }
            for line in text.split(separator: "\n").reversed() where line.contains("rate_limits") {
                guard let data = line.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let windows = extractLoggedLimits(from: object),
                      !windows.isEmpty else { continue }
                return windows
            }
        }
        return []
    }

    private nonisolated func extractLoggedLimits(from object: [String: Any]) -> [RateLimitWindow]? {
        let payload = object["payload"] as? [String: Any]
        guard let rateLimits = (payload?["rate_limits"] as? [String: Any]) ?? (object["rate_limits"] as? [String: Any]) else {
            return nil
        }
        var windows: [RateLimitWindow] = []
        if let primary = parseFlexibleWindow(rateLimits["primary"], id: "codex-primary", fallbackName: "5h") { windows.append(primary) }
        if let secondary = parseFlexibleWindow(rateLimits["secondary"], id: "codex-secondary", fallbackName: "Week") { windows.append(secondary) }
        return dedupeWindows(windows)
    }

    private nonisolated func readTodayUsedPercent() -> Double? {
        let fileManager = FileManager.default
        let root = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".codex/sessions")
        let calendar = Calendar.current
        let startToday = calendar.startOfDay(for: Date())
        guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return nil
        }

        var latestWindow: RateLimitWindow?
        var latestDate = Date.distantPast
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modified = values.contentModificationDate,
                  modified >= startToday,
                  let data = try? Data(contentsOf: url) else { continue }
            for line in data.split(separator: 0x0A) {
                guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                      let timestamp = parseDate(object["timestamp"]),
                      timestamp >= startToday,
                      timestamp > latestDate,
                      let limits = extractLoggedLimits(from: object),
                      let primary = limits.first else { continue }
                latestDate = timestamp
                latestWindow = primary
            }
        }
        return latestWindow?.usedPercent
    }

    private nonisolated func readCostSummary() -> TokenCostSummary {
        let fileManager = FileManager.default
        let home = ProcessInfo.processInfo.environment["CODEX_HOME"].map(URL.init(fileURLWithPath:))
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
        let roots = [home.appendingPathComponent("sessions"), home.appendingPathComponent("archived_sessions")]
        let calendar = Calendar.current
        let now = Date()
        let startToday = calendar.startOfDay(for: now)
        let monthComponents = calendar.dateComponents([.year, .month], from: now)
        let startMonth = calendar.date(from: monthComponents) ?? startToday
        let files = UsageCostCacheStore.jsonlFiles(roots: roots, since: startMonth)
        if let cached = UsageCostCacheStore.cached(provider: "codex", files: files, now: now) {
            return cached
        }

        var summary = TokenCostSummary.empty
        var seen = Set<String>()
        for file in files {
            guard let data = try? Data(contentsOf: file.url) else { continue }
            var currentModel: String?
            for line in data.split(separator: 0x0A) {
                guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
                if let model = extractModelMarker(from: object) { currentModel = model }
                guard let timestamp = parseDate(object["timestamp"]),
                      timestamp >= startMonth,
                      let usage = extractCodexLastTokenUsage(from: object) else { continue }

                let eventKey = "\(file.url.path)-\(object["timestamp"] ?? "")-\(usage.total)-\(usage.input)-\(usage.cachedInput)-\(usage.output)-\(usage.reasoningOutput)"
                guard seen.insert(eventKey).inserted else { continue }

                let cost = estimateCost(usage, model: currentModel)
                summary.monthTokens += usage.total
                summary.monthCost += cost
                if timestamp >= startToday {
                    summary.todayTokens += usage.total
                    summary.todayCost += cost
                }
            }
        }
        summary.isEstimated = true
        UsageCostCacheStore.save(summary, provider: "codex", files: files, now: now)
        return summary
    }

    private nonisolated struct TokenUsage {
        let input: Int
        let cachedInput: Int
        let output: Int
        let reasoningOutput: Int
        let total: Int
    }

    private nonisolated func extractCodexLastTokenUsage(from object: [String: Any]) -> TokenUsage? {
        guard let payload = object["payload"] as? [String: Any],
              payload["type"] as? String == "token_count",
              let rateLimits = payload["rate_limits"] as? [String: Any],
              rateLimits["limit_id"] as? String == "codex",
              let info = payload["info"] as? [String: Any],
              let last = info["last_token_usage"] as? [String: Any] else { return nil }

        let input = int(last["input_tokens"])
        let cachedInput = int(last["cached_input_tokens"])
        let output = int(last["output_tokens"])
        let reasoningOutput = int(last["reasoning_output_tokens"])
        let total = int(last["total_tokens"]) > 0 ? int(last["total_tokens"]) : input + output + reasoningOutput
        guard total > 0 else { return nil }
        return TokenUsage(input: input, cachedInput: cachedInput, output: output, reasoningOutput: reasoningOutput, total: total)
    }

    private nonisolated func extractModelMarker(from object: [String: Any]) -> String? {
        if let payload = object["payload"] as? [String: Any] {
            if let model = payload["model"] as? String { return model }
            if let info = payload["info"] as? [String: Any], let model = info["model"] as? String { return model }
        }
        if let model = object["model"] as? String { return model }
        return nil
    }

    private nonisolated func estimateCost(_ usage: TokenUsage, model: String?) -> Double {
        let pricing = codexPricing(for: model)
        let uncachedInput = max(0, usage.input - usage.cachedInput)
        let inputCost = Double(uncachedInput) / 1_000_000 * pricing.input
        let cachedInputCost = Double(usage.cachedInput) / 1_000_000 * pricing.cachedInput
        let outputCost = Double(usage.output + usage.reasoningOutput) / 1_000_000 * pricing.output
        return inputCost + cachedInputCost + outputCost
    }

    private nonisolated func codexPricing(for model: String?) -> UsagePricingTable.Pricing {
        UsagePricingTable.codex(model)
    }

    private nonisolated func readClaudeUsageSummary() -> ClaudeUsageSummary {
        let quota = readClaudeQuota()
        let cost = readClaudeCostSummary()
        let configured = quota.configured || cost.configured
        return ClaudeUsageSummary(
            quotaWindows: quota.windows,
            cost: cost.summary,
            isConfigured: configured,
            source: quota.source ?? cost.source
        )
    }

    private nonisolated func readClaudeQuota() -> (windows: [RateLimitWindow], configured: Bool, source: String?) {
        if let token = claudeOAuthToken(), let windows = readClaudeOAuthWindows(token: token), !windows.isEmpty {
            saveCachedClaudeQuota(windows)
            return (windows, true, "Claude OAuth API")
        }
        if let claude = claudeExecutable, let windows = readClaudeCLIWindows(claude: claude), !windows.isEmpty {
            saveCachedClaudeQuota(windows)
            return (windows, true, "Claude CLI /usage")
        }
        if let cached = readCachedClaudeQuota(), !cached.isEmpty {
            return (cached, true, "Cached quota")
        }
        if claudeDesktopInstalled() {
            return ([], false, "Claude Desktop detected; quota requires Claude Code CLI or OAuth credentials")
        }
        return ([], claudeOAuthToken() != nil || claudeExecutable != nil, "Claude quota unavailable")
    }

    private nonisolated func readCachedClaudeQuota() -> [RateLimitWindow]? {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/AIStat/quota/claude-v1.json")
        guard let data = try? Data(contentsOf: url),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        let windows = rows.compactMap { row -> RateLimitWindow? in
            guard let id = row["id"] as? String,
                  let name = row["name"] as? String,
                  let used = doubleOptional(row["usedPercent"]) else { return nil }
            let reset = dateFromAny(row["resetsAt"])
            let duration = intOptional(row["durationMinutes"])
            return RateLimitWindow(id: id, name: name, usedPercent: used, resetsAt: reset, durationMinutes: duration)
        }
        return windows.isEmpty ? nil : windows
    }

    private nonisolated func saveCachedClaudeQuota(_ windows: [RateLimitWindow]) {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/AIStat/quota/claude-v1.json")
        let rows: [[String: Any]] = windows.map { window in
            var row: [String: Any] = [
                "id": window.id,
                "name": window.name,
                "usedPercent": window.usedPercent
            ]
            if let resetsAt = window.resetsAt { row["resetsAt"] = resetsAt.timeIntervalSince1970 }
            if let duration = window.durationMinutes { row["durationMinutes"] = duration }
            return row
        }
        guard let data = try? JSONSerialization.data(withJSONObject: rows) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: [.atomic])
    }

    private nonisolated func claudeOAuthToken() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let fileCandidates = [
            ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"].map { URL(fileURLWithPath: $0).appendingPathComponent(".credentials.json") },
            home.appendingPathComponent(".claude/.credentials.json")
        ].compactMap { $0 }
        for url in fileCandidates {
            guard let data = try? Data(contentsOf: url),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if let token = recursiveString(in: object, keys: ["access_token", "accessToken", "oauthAccessToken"]), token.hasPrefix("sk-ant-oat") || token.count > 20 {
                return token
            }
        }
        return nil
    }

    private nonisolated func claudeDesktopInstalled() -> Bool {
        FileManager.default.fileExists(atPath: "/Applications/Claude.app")
            || FileManager.default.fileExists(atPath: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Claude").path)
    }

    private nonisolated func readClaudeOAuthWindows(token: String) -> [RateLimitWindow]? {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let data = performRequest(request, timeout: 8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return parseClaudeOAuthWindows(from: object)
    }

    private nonisolated func parseClaudeOAuthWindows(from object: [String: Any]) -> [RateLimitWindow] {
        let mappings: [(String, String, String)] = [
            ("five_hour", "claude-five-hour", "5h"),
            ("seven_day", "claude-seven-day", "Week"),
            ("seven_day_sonnet", "claude-sonnet-week", "Sonnet Week"),
            ("seven_day_opus", "claude-opus-week", "Opus Week"),
            ("seven_day_routines", "claude-routines-week", "Routines Week"),
            ("seven_day_cowork", "claude-cowork-week", "Cowork Week")
        ]
        var windows: [RateLimitWindow] = []
        let usage = (object["usage"] as? [String: Any]) ?? object
        for (key, id, title) in mappings {
            if let window = parseFlexibleWindow(usage[key] ?? object[key], id: id, fallbackName: title) {
                windows.append(window)
            }
        }
        return dedupeWindows(windows)
    }

    private nonisolated func readClaudeCLIWindows(claude: String) -> [RateLimitWindow]? {
        let quotedClaude = claude.replacingOccurrences(of: "'", with: "'\\''")
        let command = "printf '/usage\\n/status\\n' | '\(quotedClaude)' --allowed-tools '' 2>/dev/null"
        guard let result = runPtyShellCommand(command, timeout: 10), result.exitCode == 0 else { return nil }
        return parseStatusWindows(result.output, provider: "claude")
    }

    private nonisolated func readClaudeCostSummary() -> (summary: TokenCostSummary, configured: Bool, source: String) {
        let roots = claudeLogRoots()
        guard !roots.isEmpty else { return (.empty, false, "Claude logs not found") }

        let calendar = Calendar.current
        let now = Date()
        let startToday = calendar.startOfDay(for: now)
        let monthComponents = calendar.dateComponents([.year, .month], from: now)
        let startMonth = calendar.date(from: monthComponents) ?? startToday
        let files = UsageCostCacheStore.jsonlFiles(roots: roots, since: startMonth)
        let foundLogs = !files.isEmpty
        if let cached = UsageCostCacheStore.cached(provider: "claude", files: files, now: now) {
            return (cached, foundLogs, foundLogs ? "Claude local logs" : "Claude logs not found")
        }

        var summary = TokenCostSummary.empty
        var seen = Set<String>()
        for file in files {
            guard let data = try? Data(contentsOf: file.url) else { continue }
            for line in data.split(separator: 0x0A) {
                guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                      !isVertexClaudeLog(object),
                      let timestamp = parseDate(object["timestamp"] ?? object["created_at"]),
                      timestamp >= startMonth,
                      let usage = extractClaudeUsage(from: object) else { continue }

                let eventKey = "\(file.url.path)-\(object["uuid"] ?? object["id"] ?? object["requestId"] ?? object["timestamp"] ?? UUID().uuidString)-\(usage.total)"
                guard seen.insert(eventKey).inserted else { continue }

                let cost = estimateClaudeCost(usage, model: extractClaudeModel(from: object))
                summary.monthTokens += usage.total
                summary.monthCost += cost
                if timestamp >= startToday {
                    summary.todayTokens += usage.total
                    summary.todayCost += cost
                }
            }
        }
        summary.isEstimated = true
        UsageCostCacheStore.save(summary, provider: "claude", files: files, now: now)
        return (summary, foundLogs, foundLogs ? "Claude local logs" : "Claude logs not found")
    }

    private nonisolated func claudeLogRoots() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var candidates: [URL] = []
        if let env = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"] {
            candidates.append(contentsOf: env.split(separator: ",").map { URL(fileURLWithPath: String($0)).appendingPathComponent("projects") })
        }
        candidates.append(home.appendingPathComponent(".config/claude/projects"))
        candidates.append(home.appendingPathComponent(".claude/projects"))
        candidates.append(home.appendingPathComponent(".pi/agent/sessions"))
        return candidates.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private nonisolated func extractClaudeUsage(from object: [String: Any]) -> TokenUsage? {
        if let type = object["type"] as? String, type != "assistant" && object["message"] == nil && object["usage"] == nil {
            return nil
        }
        let usage = (object["usage"] as? [String: Any])
            ?? ((object["message"] as? [String: Any])?["usage"] as? [String: Any])
            ?? ((object["response"] as? [String: Any])?["usage"] as? [String: Any])
        guard let usage else { return nil }

        let input = int(usage["input_tokens"])
        let cacheCreation = int(usage["cache_creation_input_tokens"])
        let cacheRead = int(usage["cache_read_input_tokens"])
        let output = int(usage["output_tokens"])
        let total = input + cacheCreation + cacheRead + output
        guard total > 0 else { return nil }
        return TokenUsage(input: input + cacheCreation, cachedInput: cacheRead, output: output, reasoningOutput: 0, total: total)
    }

    private nonisolated func extractClaudeModel(from object: [String: Any]) -> String? {
        if let model = object["model"] as? String { return model }
        if let message = object["message"] as? [String: Any], let model = message["model"] as? String { return model }
        return nil
    }

    private nonisolated func estimateClaudeCost(_ usage: TokenUsage, model: String?) -> Double {
        let pricing = claudePricing(for: model)
        let inputCost = Double(max(0, usage.input)) / 1_000_000 * pricing.input
        let cachedReadCost = Double(usage.cachedInput) / 1_000_000 * pricing.cachedInput
        let outputCost = Double(usage.output) / 1_000_000 * pricing.output
        return inputCost + cachedReadCost + outputCost
    }

    private nonisolated func claudePricing(for model: String?) -> UsagePricingTable.Pricing {
        UsagePricingTable.claude(model)
    }

    private nonisolated func isVertexClaudeLog(_ object: [String: Any]) -> Bool {
        if let metadata = object["metadata"] as? [String: Any], metadata["provider"] as? String == "vertexai" {
            return true
        }
        let text = String(describing: object)
        return text.contains("req_vrtx_") || text.contains("msg_vrtx_")
    }

    private nonisolated func parseFlexibleWindow(_ value: Any?, id: String, fallbackName: String) -> RateLimitWindow? {
        guard let dict = value as? [String: Any] else { return nil }
        let duration = windowDurationMinutes(from: dict)
        var used = doubleOptional(dict["usedPercent"] ?? dict["used_percent"] ?? dict["percent_used"] ?? dict["usage_percent"] ?? dict["utilization"] ?? dict["utilization_percent"])
        if let value = used, value <= 1 { used = value * 100 }
        if used == nil, let remaining = doubleOptional(dict["remainingPercent"] ?? dict["remaining_percent"] ?? dict["percent_remaining"]) {
            used = 100 - (remaining <= 1 ? remaining * 100 : remaining)
        }
        guard let used else { return nil }
        let reset = dateFromAny(dict["resetsAt"] ?? dict["resets_at"] ?? dict["reset_at"] ?? dict["resetAt"] ?? dict["resetTime"] ?? dict["reset_time"])
        let rawName = (dict["name"] as? String) ?? (dict["title"] as? String) ?? (dict["limit_name"] as? String)
        let name = normalizedWindowName(rawName ?? fallbackName, durationMinutes: duration)
        return RateLimitWindow(id: id, name: name, usedPercent: max(0, min(100, used)), resetsAt: reset, durationMinutes: duration)
    }

    private nonisolated func windowDurationMinutes(from dict: [String: Any]) -> Int? {
        if let minutes = intOptional(dict["windowDurationMins"] ?? dict["window_duration_mins"] ?? dict["window_minutes"] ?? dict["duration_minutes"] ?? dict["durationMins"]) {
            return minutes
        }
        if let seconds = intOptional(dict["limit_window_seconds"] ?? dict["window_seconds"] ?? dict["duration_seconds"] ?? dict["durationSeconds"]) {
            return seconds / 60
        }
        return nil
    }

    private nonisolated func normalizedWindowName(_ fallback: String, durationMinutes: Int?) -> String {
        switch durationMinutes {
        case 300: return "5h"
        case 10_080: return "Week"
        case 43_200: return "30d"
        default: break
        }
        let lower = fallback.lowercased()
        if lower.contains("five") || lower.contains("5h") || lower.contains("session") { return "5h" }
        if lower.contains("seven") || lower.contains("week") || lower.contains("7d") { return "Week" }
        if lower.contains("month") || lower.contains("30d") { return "30d" }
        return fallback
    }

    private nonisolated func parseStatusWindows(_ text: String, provider: String) -> [RateLimitWindow] {
        let clean = text.replacingOccurrences(of: #"\u001B\[[0-9;?]*[ -/]*[@-~]"#, with: "", options: .regularExpression)
        var windows: [RateLimitWindow] = []
        for line in clean.components(separatedBy: .newlines) {
            let lower = line.lowercased()
            guard lower.contains("limit") || lower.contains("session") || lower.contains("week") else { continue }
            guard let percent = firstPercent(in: line) else { continue }
            let name: String
            if lower.contains("week") || lower.contains("current week") { name = "Week" }
            else if lower.contains("5h") || lower.contains("five") || lower.contains("session") { name = "5h" }
            else { continue }
            windows.append(RateLimitWindow(id: "\(provider)-\(name.lowercased())", name: name, usedPercent: percent, resetsAt: nil, durationMinutes: name == "5h" ? 300 : 10_080))
        }
        return dedupeWindows(windows)
    }

    private nonisolated func firstPercent(in line: String) -> Double? {
        guard let match = line.range(of: #"[0-9]+(?:\.[0-9]+)?\s*%"#, options: .regularExpression) else { return nil }
        let raw = line[match].replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
        guard let value = Double(raw) else { return nil }
        let lower = line.lowercased()
        return lower.contains("left") || lower.contains("remaining") ? 100 - value : value
    }

    private nonisolated func dedupeWindows(_ windows: [RateLimitWindow]) -> [RateLimitWindow] {
        var seen = Set<String>()
        var result: [RateLimitWindow] = []
        for window in windows {
            let key = window.name
            guard seen.insert(key).inserted else { continue }
            result.append(window)
        }
        return result
    }

    private nonisolated func performRequest(_ request: URLRequest, timeout: TimeInterval) -> Data? {
        let semaphore = DispatchSemaphore(value: 0)
        var responseData: Data?
        var mutableRequest = request
        mutableRequest.timeoutInterval = timeout
        let task = URLSession.shared.dataTask(with: mutableRequest) { data, response, _ in
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                responseData = data
            }
            semaphore.signal()
        }
        task.resume()
        if semaphore.wait(timeout: .now() + timeout + 1) == .timedOut {
            task.cancel()
            return nil
        }
        return responseData
    }

    private nonisolated struct ProcessResult {
        let output: String
        let exitCode: Int32
    }

    private nonisolated func runProcess(_ executable: String, arguments: [String], timeout: TimeInterval) -> ProcessResult? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = output
        do {
            try process.run()
        } catch {
            return nil
        }
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            semaphore.signal()
        }
        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            return nil
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        return ProcessResult(output: String(decoding: data, as: UTF8.self), exitCode: process.terminationStatus)
    }

    private nonisolated func runPtyShellCommand(_ command: String, timeout: TimeInterval) -> ProcessResult? {
        if FileManager.default.isExecutableFile(atPath: "/usr/bin/script") {
            return runProcess("/usr/bin/script", arguments: ["-q", "/dev/null", "/bin/zsh", "-lc", command], timeout: timeout)
        }
        return runProcess("/bin/zsh", arguments: ["-lc", command], timeout: timeout)
    }

    private nonisolated func dateFromAny(_ value: Any?) -> Date? {
        if let number = value as? NSNumber { return Date(timeIntervalSince1970: number.doubleValue) }
        if let double = value as? Double { return Date(timeIntervalSince1970: double) }
        if let int = value as? Int { return Date(timeIntervalSince1970: Double(int)) }
        return parseDate(value)
    }

    private nonisolated func parseDate(_ value: Any?) -> Date? {
        guard let string = value as? String else { return nil }
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let formatter = ISO8601DateFormatter()
        return fractionalFormatter.date(from: string) ?? formatter.date(from: string)
    }

    private nonisolated func int(_ value: Any?) -> Int {
        intOptional(value) ?? 0
    }

    private nonisolated func intOptional(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let int = value as? Int { return int }
        if let string = value as? String { return Int(string) }
        return nil
    }

    private nonisolated func doubleOptional(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let string = value as? String { return Double(string) }
        return nil
    }

    private nonisolated func recursiveString(in object: Any, keys: Set<String>) -> String? {
        if let dict = object as? [String: Any] {
            for key in keys {
                if let value = dict[key] as? String, !value.isEmpty { return value }
            }
            for value in dict.values {
                if let found = recursiveString(in: value, keys: keys) { return found }
            }
        } else if let array = object as? [Any] {
            for item in array {
                if let found = recursiveString(in: item, keys: keys) { return found }
            }
        }
        return nil
    }
}
