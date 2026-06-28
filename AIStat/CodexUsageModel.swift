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
    private var pollingTask: Task<Void, Never>?

    /// 应用设置（刷新间隔、Provider 启用状态）。
    private weak var settings: AppSettings?

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

    deinit {
        refreshTask?.cancel()
        pollingTask?.cancel()
    }

    /// 绑定设置并按当前刷新间隔启动轮询。
    func bind(settings: AppSettings) {
        self.settings = settings
        restartPolling(interval: settings.refreshInterval)
    }

    /// 按新的刷新间隔重启轮询任务。
    func restartPolling(interval: RefreshInterval) {
        pollingTask?.cancel()
        guard let seconds = interval.seconds else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                guard let self, !Task.isCancelled else { return }
                self.refresh()
            }
        }
    }

    /// Provider 启用状态变化时调用：被禁用的立即移除，启用的立即用缓存占位并强制刷新。
    func applyEnabledProviders() {
        guard let settings else { return }

        // 1) 立即移除被禁用的 Provider（同步、瞬时）。
        var current = providers.filter { settings.isProviderEnabled($0.id) }

        // 2) 对「已启用但当前未展示」的 Provider，立即插入占位项，避免开启后空等到下次刷新。
        let shownIDs = Set(current.map(\.id))
        for provider in registeredProviders where settings.isProviderEnabled(provider.id) && !shownIDs.contains(provider.id) {
            // 优先用缓存，无缓存则放一个「刷新中」占位。
            let placeholder = provider.cachedUsage() ?? ProviderUsage(
                id: provider.id,
                name: provider.displayName,
                symbolName: provider.symbolName,
                accentName: provider.accentName,
                status: .stale,
                source: "Refreshing…",
                quotaWindows: [],
                cost: .empty,
                isConfigured: true
            )
            current.append(placeholder)
        }

        // 3) 按注册顺序排序后立即展示（用户瞬间就能看到开启的 Provider）。
        let order = registeredProviders.map(\.id)
        providers = current.sorted {
            (order.firstIndex(of: $0.id) ?? .max) < (order.firstIndex(of: $1.id) ?? .max)
        }

        // 4) 强制刷新以最新启用状态拉取真实数据替换占位。
        refresh(force: true)
    }

    /// 当前启用的 Provider id 集合（无 settings 时全部启用）。
    private var enabledProviderIDs: Set<String> {
        guard let settings else { return Set(registeredProviders.map(\.id)) }
        return Set(registeredProviders.map(\.id).filter { settings.isProviderEnabled($0) })
    }

    /// Codex 周额度剩余百分比，供其它视图复用。
    var weeklyRemainingPercent: Double? {
        providers.first { $0.id == "codex" }?
            .quotaWindows.first { $0.name == "Week" }?
            .remainingPercent
    }

    /// 刷新所有已启用的 Provider。
    /// - Parameter force: 为 true 时取消在途刷新并立即重跑（用于设置变更后立即生效）。
    func refresh(force: Bool = false) {
        if force {
            refreshTask?.cancel()
        } else if isRefreshing {
            return
        }
        isRefreshing = true

        // 只拉取已启用的 Provider（启动刷新时的快照）。
        let registered = registeredProviders.filter { enabledProviderIDs.contains($0.id) }
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

            // 回写前以「最新」启用状态再过滤一次，避免刷新期间用户改了开关导致状态错乱。
            let currentlyEnabled = enabledProviderIDs
            fresh = fresh.filter { currentlyEnabled.contains($0.id) }

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
