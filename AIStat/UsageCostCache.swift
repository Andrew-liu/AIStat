import Foundation

struct UsageCostFile: Sendable {
    let url: URL
    let signature: String
}

enum UsageCostCacheStore {
    private nonisolated struct Payload: Codable {
        var version: Int
        var dayKey: String
        var monthKey: String
        var signatureHash: String
        var todayTokens: Int
        var monthTokens: Int
        var todayCost: Double
        var monthCost: Double
        var isEstimated: Bool
        var savedAt: Date
    }

    nonisolated static func jsonlFiles(roots: [URL], since startDate: Date) -> [UsageCostFile] {
        let fileManager = FileManager.default
        var files: [UsageCostFile] = []
        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let url as URL in enumerator where url.pathExtension == "jsonl" {
                guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                      let modified = values.contentModificationDate,
                      modified >= startDate else { continue }
                let size = values.fileSize ?? 0
                let signature = "\(url.path)|\(Int(modified.timeIntervalSince1970))|\(size)"
                files.append(UsageCostFile(url: url, signature: signature))
            }
        }
        return files.sorted { $0.url.path < $1.url.path }
    }

    nonisolated static func cached(provider: String, files: [UsageCostFile], now: Date = Date()) -> TokenCostSummary? {
        guard let payload = readPayload(provider: provider) else { return nil }
        let keys = periodKeys(now: now)
        guard payload.version == 1,
              payload.dayKey == keys.day,
              payload.monthKey == keys.month,
              payload.signatureHash == signatureHash(files) else { return nil }
        return TokenCostSummary(
            todayTokens: payload.todayTokens,
            monthTokens: payload.monthTokens,
            todayCost: payload.todayCost,
            monthCost: payload.monthCost,
            isEstimated: payload.isEstimated
        )
    }

    nonisolated static func save(_ summary: TokenCostSummary, provider: String, files: [UsageCostFile], now: Date = Date()) {
        let keys = periodKeys(now: now)
        let payload = Payload(
            version: 1,
            dayKey: keys.day,
            monthKey: keys.month,
            signatureHash: signatureHash(files),
            todayTokens: summary.todayTokens,
            monthTokens: summary.monthTokens,
            todayCost: summary.todayCost,
            monthCost: summary.monthCost,
            isEstimated: summary.isEstimated,
            savedAt: now
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let url = cacheURL(provider: provider)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: [.atomic])
    }

    private nonisolated static func readPayload(provider: String) -> Payload? {
        let url = cacheURL(provider: provider)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }

    private nonisolated static func cacheURL(provider: String) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/AIStat/cost-usage/\(provider)-v1.json")
    }

    private nonisolated static func periodKeys(now: Date) -> (day: String, month: String) {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: now)
        formatter.dateFormat = "yyyy-MM"
        return (day, formatter.string(from: now))
    }

    private nonisolated static func signatureHash(_ files: [UsageCostFile]) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        let prime: UInt64 = 1_099_511_628_211
        for byte in files.map(\.signature).joined(separator: "\n").utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return String(hash, radix: 16)
    }
}

enum UsagePricingTable {
    struct Pricing: Sendable {
        let input: Double
        let cachedInput: Double
        let output: Double
    }

    nonisolated static func codex(_ model: String?) -> Pricing {
        let name = (model ?? "").lowercased()
        if name.contains("mini") { return Pricing(input: 0.25, cachedInput: 0.025, output: 2.0) }
        if name.contains("gpt-5.4") || name.contains("gpt-5.3") || name.contains("codex") {
            return Pricing(input: 1.25, cachedInput: 0.125, output: 10.0)
        }
        return Pricing(input: 1.25, cachedInput: 0.125, output: 10.0)
    }

    nonisolated static func claude(_ model: String?) -> Pricing {
        let name = (model ?? "").lowercased()
        if name.contains("haiku") { return Pricing(input: 0.80, cachedInput: 0.08, output: 4.0) }
        if name.contains("opus") { return Pricing(input: 15.0, cachedInput: 1.50, output: 75.0) }
        if name.contains("sonnet") { return Pricing(input: 3.0, cachedInput: 0.30, output: 15.0) }
        return Pricing(input: 3.0, cachedInput: 0.30, output: 15.0)
    }
}
