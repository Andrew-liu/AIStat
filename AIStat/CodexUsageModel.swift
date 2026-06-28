import Foundation
import AppKit
import Combine

struct RateLimitWindow: Sendable {
    let id: String
    let name: String
    let usedPercent: Double
    let resetsAt: Date?
    let durationMinutes: Int?

    var remainingPercent: Double {
        max(0, min(100, 100 - usedPercent))
    }
}

struct TokenCostSummary: Sendable {
    var todayTokens = 0
    var monthTokens = 0
    var todayCost: Double = 0
    var monthCost: Double = 0
    var isEstimated = true

    nonisolated static let empty = TokenCostSummary()
}

struct ClaudeUsageSummary: Sendable {
    var quotaWindows: [RateLimitWindow] = []
    var cost = TokenCostSummary.empty
    var isConfigured = false
    var source = "Claude not configured"

    nonisolated static let empty = ClaudeUsageSummary()
}

struct CodexUsageSummary: Sendable {
    var quotaWindows: [RateLimitWindow] = []
    var fiveHour: RateLimitWindow?
    var weekly: RateLimitWindow?
    var todayUsedPercent: Double?
    var todayUnusedPercent: Double?
    var cost = TokenCostSummary.empty
    var claude = ClaudeUsageSummary.empty
    var isInstalled = false
    var isLoggedIn = false
    var source = "Waiting for refresh"
    var updatedAt: Date?

    static let empty = CodexUsageSummary()

    nonisolated init(
        quotaWindows: [RateLimitWindow] = [],
        fiveHour: RateLimitWindow? = nil,
        weekly: RateLimitWindow? = nil,
        todayUsedPercent: Double? = nil,
        todayUnusedPercent: Double? = nil,
        cost: TokenCostSummary = .empty,
        claude: ClaudeUsageSummary = .empty,
        isInstalled: Bool = false,
        isLoggedIn: Bool = false,
        source: String = "Waiting for refresh",
        updatedAt: Date? = nil
    ) {
        self.quotaWindows = quotaWindows
        self.fiveHour = fiveHour
        self.weekly = weekly
        self.todayUsedPercent = todayUsedPercent
        self.todayUnusedPercent = todayUnusedPercent
        self.cost = cost
        self.claude = claude
        self.isInstalled = isInstalled
        self.isLoggedIn = isLoggedIn
        self.source = source
        self.updatedAt = updatedAt
    }
}

@MainActor
final class CodexUsageModel: ObservableObject {
    /// 平级 Provider 列表（统一抽象的对外数据）。
    @Published private(set) var providers: [ProviderUsage] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var updatedAt: Date?

    private let reader = CodexUsageReader()
    private let registeredProviders: [UsageProvider]
    private var refreshTask: Task<Void, Never>?

    init() {
        let reader = self.reader
        self.registeredProviders = UsageProviderRegistry.makeProviders(reader: reader)

        // 启动时先用缓存填充，避免空白。
        let cached = registeredProviders.compactMap { $0.cachedUsage() }
        if !cached.isEmpty {
            providers = cached
            updatedAt = Date()
        }
        refresh()
    }

    /// Codex 周额度剩余百分比，供其它视图复用。
    var weeklyRemainingPercent: Double? {
        providers.first { $0.id == "codex" }?
            .quotaWindows.first { $0.name == "Week" }?
            .remainingPercent
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        refreshTask?.cancel()

        let registered = registeredProviders
        let previous = providers
        refreshTask = Task {
            // 并发拉取所有 Provider。
            var fresh: [ProviderUsage] = await withTaskGroup(of: (Int, ProviderUsage).self) { group in
                for (index, provider) in registered.enumerated() {
                    group.addTask { (index, await provider.fetchUsage()) }
                }
                var results: [(Int, ProviderUsage)] = []
                for await item in group { results.append(item) }
                return results.sorted { $0.0 < $1.0 }.map(\.1)
            }
            guard !Task.isCancelled else { return }

            // 「永不空白」：本次额度为空但上次有值时，回退到上次额度。
            fresh = fresh.map { current in
                guard current.quotaWindows.isEmpty,
                      let prior = previous.first(where: { $0.id == current.id }),
                      !prior.quotaWindows.isEmpty else { return current }
                return ProviderUsage(
                    id: current.id,
                    name: current.name,
                    symbolName: current.symbolName,
                    accentName: current.accentName,
                    status: current.status,
                    source: "Last known quota",
                    quotaWindows: prior.quotaWindows,
                    cost: current.cost,
                    isConfigured: true
                )
            }

            providers = fresh
            updatedAt = Date()
            isRefreshing = false
        }
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }
}
