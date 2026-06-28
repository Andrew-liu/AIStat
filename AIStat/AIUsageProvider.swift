import Foundation
import SwiftUI

enum AIProviderStatus: String, Sendable {
    case operational = "Operational"
    case unavailable = "Unavailable"
    case stale = "Stale"
    case limited = "Limited"
}

struct AIUsageMetric: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let usedText: String
    let remainingText: String
    let resetText: String
    let percentUsed: Double?
    let accentName: String

    var percentRemaining: Double? {
        percentUsed.map { max(0, min(100, 100 - $0)) }
    }
}

struct AIUsageProvider: Identifiable, Sendable {
    let id: String
    let name: String
    let modelName: String
    let symbolName: String
    let accentName: String
    let status: AIProviderStatus
    let authSource: String
    let metrics: [AIUsageMetric]
    let todayTokensText: String
    let todayCostText: String
    let monthTokensText: String
    let monthCostText: String
    let note: String

    var primaryMetric: AIUsageMetric? {
        metrics.first
    }
}

enum AIUsageProviderFactory {
    static func providers(from summary: CodexUsageSummary) -> [AIUsageProvider] {
        [
            codexProvider(from: summary),
            claudeProvider(from: summary.claude)
        ]
    }

    private static func codexProvider(from summary: CodexUsageSummary) -> AIUsageProvider {
        let installed = summary.isInstalled
        let windows = codexWindows(from: summary)
        let hasUsageData = !windows.isEmpty || summary.cost.todayTokens > 0 || summary.cost.monthTokens > 0
        let status: AIProviderStatus = hasUsageData ? .operational : (installed ? .stale : .unavailable)

        return AIUsageProvider(
            id: "codex",
            name: "Codex",
            modelName: "OAuth API / CLI RPC",
            symbolName: "terminal.fill",
            accentName: "purple",
            status: status,
            authSource: summary.source,
            metrics: windows.map { quotaMetric(providerID: "codex", window: $0) },
            todayTokensText: formatTokens(summary.cost.todayTokens),
            todayCostText: formatCost(summary.cost.todayCost, estimated: summary.cost.isEstimated),
            monthTokensText: formatTokens(summary.cost.monthTokens),
            monthCostText: formatCost(summary.cost.monthCost, estimated: summary.cost.isEstimated),
            note: summary.source
        )
    }

    private static func codexWindows(from summary: CodexUsageSummary) -> [RateLimitWindow] {
        if !summary.quotaWindows.isEmpty { return summary.quotaWindows }
        let explicit = [summary.fiveHour, summary.weekly].compactMap { $0 }
        if !explicit.isEmpty { return explicit }
        if let used = summary.todayUsedPercent {
            return [RateLimitWindow(id: "codex-fallback", name: "Quota", usedPercent: used, resetsAt: nil, durationMinutes: nil)]
        }
        return []
    }

    private static func claudeProvider(from summary: ClaudeUsageSummary) -> AIUsageProvider {
        let hasUsageData = !summary.quotaWindows.isEmpty || summary.cost.todayTokens > 0 || summary.cost.monthTokens > 0
        let status: AIProviderStatus = hasUsageData ? .operational : (summary.source.contains("Desktop detected") ? .limited : .unavailable)
        return AIUsageProvider(
            id: "claude",
            name: "Claude",
            modelName: "OAuth API / CLI / local logs",
            symbolName: "sparkles",
            accentName: "purple",
            status: status,
            authSource: summary.source,
            metrics: summary.quotaWindows.map { quotaMetric(providerID: "claude", window: $0) },
            todayTokensText: formatTokens(summary.cost.todayTokens),
            todayCostText: formatCost(summary.cost.todayCost, estimated: summary.cost.isEstimated),
            monthTokensText: formatTokens(summary.cost.monthTokens),
            monthCostText: formatCost(summary.cost.monthCost, estimated: summary.cost.isEstimated),
            note: summary.source
        )
    }

    private static func quotaMetric(providerID: String, window: RateLimitWindow) -> AIUsageMetric {
        AIUsageMetric(
            id: window.id.isEmpty ? "\(providerID)-\(window.name.lowercased())" : window.id,
            title: window.name,
            subtitle: "\(window.name) quota",
            usedText: percent(window.usedPercent, suffix: " used"),
            remainingText: percent(window.remainingPercent, suffix: " left"),
            resetText: resetText(window.resetsAt),
            percentUsed: window.usedPercent,
            accentName: accentName(for: window.name)
        )
    }

    private static func accentName(for title: String) -> String {
        let lower = title.lowercased()
        if lower.contains("5h") || lower.contains("session") { return "orange" }
        if lower.contains("week") { return "purple" }
        if lower.contains("opus") { return "red" }
        if lower.contains("sonnet") { return "blue" }
        if lower.contains("30") || lower.contains("month") { return "green" }
        return "purple"
    }

    private static func percent(_ value: Double?, suffix: String = "") -> String {
        guard let value else { return "--\(suffix)" }
        return "\(Int(max(0, min(100, value)).rounded()))%\(suffix)"
    }

    private static func resetText(_ date: Date?) -> String {
        guard let date else { return "reset unknown" }
        let seconds = Int(date.timeIntervalSinceNow)
        guard seconds > 0 else { return "reset passed" }
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        if days > 0 {
            return "resets in \(days)d \(hours)h"
        }
        if hours > 0 {
            return "resets in \(hours)h \(minutes)m"
        }
        return "resets in \(max(1, minutes))m"
    }

    private static func formatTokens(_ tokens: Int) -> String {
        guard tokens > 0 else { return "0 tokens" }
        if tokens >= 1_000_000 {
            return String(format: "%.2fM tokens", Double(tokens) / 1_000_000)
        }
        if tokens >= 1_000 {
            return String(format: "%.1fK tokens", Double(tokens) / 1_000)
        }
        return "\(tokens) tokens"
    }

    private static func formatCost(_ cost: Double, estimated: Bool) -> String {
        let prefix = estimated ? "~" : ""
        return "\(prefix)$\(String(format: "%.2f", max(0, cost)))"
    }
}
