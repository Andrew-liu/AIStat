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
    @Published private(set) var summary = CodexUsageSummary.empty
    @Published private(set) var isRefreshing = false

    private let reader = CodexUsageReader()
    private var refreshTask: Task<Void, Never>?

    init() {
        if let cached = reader.readCachedSummary() {
            summary = cached
        }
        refresh()
    }

    var weeklyRemainingPercent: Double? {
        summary.weekly?.remainingPercent
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        refreshTask?.cancel()
        refreshTask = Task {
            var value = await reader.readSummary()
            guard !Task.isCancelled else { return }
            if value.quotaWindows.isEmpty, !summary.quotaWindows.isEmpty {
                value.quotaWindows = summary.quotaWindows
                value.fiveHour = summary.fiveHour
                value.weekly = summary.weekly
                value.todayUsedPercent = summary.todayUsedPercent
                value.todayUnusedPercent = summary.todayUnusedPercent
                value.source = "Last known quota"
            }
            if value.claude.quotaWindows.isEmpty, !summary.claude.quotaWindows.isEmpty {
                value.claude.quotaWindows = summary.claude.quotaWindows
                value.claude.source = "Last known quota"
                value.claude.isConfigured = true
            }
            summary = value
            isRefreshing = false
        }
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }
}
