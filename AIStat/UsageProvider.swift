import Foundation

/// 一个 AI Provider 的完整用量状态（平级模型，所有 Provider 通用）。
///
/// 这是 Provider 抽象的对外统一模型：无论底层来源是 OAuth API、CLI、本地日志还是缓存，
/// 每个 Provider 都把结果归一化为「额度窗口 + 成本 + 状态 + 来源」，由同一套 UI 复用渲染。
struct ProviderUsage: Identifiable, Sendable {
    let id: String
    let name: String
    let symbolName: String
    let accentName: String
    let status: AIProviderStatus
    let source: String
    let quotaWindows: [RateLimitWindow]
    let cost: TokenCostSummary
    let isConfigured: Bool

    var hasUsageData: Bool {
        !quotaWindows.isEmpty || cost.todayTokens > 0 || cost.monthTokens > 0
    }
}

/// 所有 AI 用量 Provider 的统一协议。
///
/// 新增一个 Provider 只需实现本协议，并在 `UsageProviderRegistry` 注册即可，UI 层无需改动。
protocol UsageProvider: Sendable {
    /// 稳定标识，如 "codex" / "claude" / 未来的 "gemini"。
    var id: String { get }
    var displayName: String { get }
    var symbolName: String { get }
    var accentName: String { get }

    /// 在线读取（OAuth / CLI / 日志），失败时返回最佳可得结果。
    func fetchUsage() async -> ProviderUsage
    /// 启动时的快速缓存读取，用于「永不空白」；无缓存时返回 nil。
    func cachedUsage() -> ProviderUsage?
}

/// Provider 的静态展示元信息（与运行时数据无关），用于设置界面等需要列出全部 Provider 的场景。
struct ProviderDescriptor: Identifiable, Sendable {
    let id: String
    let name: String
    let symbolName: String
    let accentName: String
}

/// Provider 注册表：集中声明当前启用的所有 Provider。
///
/// 接入新 Provider 时，只需在这里追加一个实例与对应描述符。
enum UsageProviderRegistry {
    /// 所有已注册 Provider 的静态描述（含被禁用的）。
    static let descriptors: [ProviderDescriptor] = [
        ProviderDescriptor(id: "codex", name: "Codex", symbolName: "terminal.fill", accentName: "purple"),
        ProviderDescriptor(id: "claude", name: "Claude", symbolName: "sparkles", accentName: "purple")
    ]

    /// 所有 Provider 共享同一个底层 reader，避免重复的可执行文件探测等开销。
    static func makeProviders(reader: CodexUsageReader) -> [UsageProvider] {
        [
            CodexProvider(reader: reader),
            ClaudeProvider(reader: reader)
        ]
    }
}

/// Codex Provider：OAuth API → CLI RPC → 本地 session 日志 → 缓存。
struct CodexProvider: UsageProvider {
    let id = "codex"
    let displayName = "Codex"
    let symbolName = "terminal.fill"
    let accentName = "purple"

    private let reader: CodexUsageReader

    init(reader: CodexUsageReader) {
        self.reader = reader
    }

    func fetchUsage() async -> ProviderUsage {
        await reader.loadCodexUsage()
    }

    func cachedUsage() -> ProviderUsage? {
        reader.cachedCodexUsage()
    }
}

/// Claude Provider：OAuth 凭据 → CLI `/usage` → 缓存 → Desktop 检测降级。
struct ClaudeProvider: UsageProvider {
    let id = "claude"
    let displayName = "Claude"
    let symbolName = "sparkles"
    let accentName = "purple"

    private let reader: CodexUsageReader

    init(reader: CodexUsageReader) {
        self.reader = reader
    }

    func fetchUsage() async -> ProviderUsage {
        await reader.loadClaudeUsage()
    }

    func cachedUsage() -> ProviderUsage? {
        reader.cachedClaudeUsage()
    }
}
