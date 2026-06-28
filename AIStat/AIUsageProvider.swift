import Foundation
import SwiftUI

enum AIProviderStatus: String, Sendable {
    case operational = "Operational"
    case unavailable = "Unavailable"
    case stale = "Stale"
    case limited = "Limited"
}

/// 单个额度窗口的展示数据（由 `RateLimitWindow` 派生）。
struct AIUsageMetric: Identifiable, Sendable {
    let id: String
    let title: String
    let usedText: String
    let remainingText: String
    let resetText: String
    let percentUsed: Double?
    let accentName: String
}

// MARK: - ProviderUsage 展示映射
//
// 把统一的 `ProviderUsage` 数据模型映射为 UI 所需的展示文本，UI 层只依赖这些计算属性。
extension ProviderUsage {
    var note: String { source }
    var authSource: String { source }

    var todayTokensText: String { AIUsageFormat.tokens(cost.todayTokens) }
    var todayCostText: String { AIUsageFormat.cost(cost.todayCost, estimated: cost.isEstimated) }
    var monthTokensText: String { AIUsageFormat.tokens(cost.monthTokens) }
    var monthCostText: String { AIUsageFormat.cost(cost.monthCost, estimated: cost.isEstimated) }

    var metrics: [AIUsageMetric] {
        quotaWindows.map { window in
            AIUsageMetric(
                id: window.id.isEmpty ? "\(id)-\(window.name.lowercased())" : window.id,
                title: window.name,
                usedText: AIUsageFormat.percent(window.usedPercent, suffix: " used"),
                remainingText: AIUsageFormat.percent(window.remainingPercent, suffix: " left"),
                resetText: AIUsageFormat.resetText(window.resetsAt),
                percentUsed: window.usedPercent,
                accentName: AIUsageFormat.accentName(for: window.name)
            )
        }
    }
}

/// AI 用量展示格式化工具。
enum AIUsageFormat {
    static func accentName(for title: String) -> String {
        let lower = title.lowercased()
        if lower.contains("5h") || lower.contains("session") { return "orange" }
        if lower.contains("week") { return "purple" }
        if lower.contains("opus") { return "red" }
        if lower.contains("sonnet") { return "blue" }
        if lower.contains("30") || lower.contains("month") { return "green" }
        return "purple"
    }

    static func percent(_ value: Double?, suffix: String = "") -> String {
        guard let value else { return "--\(suffix)" }
        return "\(Int(max(0, min(100, value)).rounded()))%\(suffix)"
    }

    static func resetText(_ date: Date?) -> String {
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

    static func tokens(_ tokens: Int) -> String {
        guard tokens > 0 else { return "0 tokens" }
        if tokens >= 1_000_000 {
            return String(format: "%.2fM tokens", Double(tokens) / 1_000_000)
        }
        if tokens >= 1_000 {
            return String(format: "%.1fK tokens", Double(tokens) / 1_000)
        }
        return "\(tokens) tokens"
    }

    static func cost(_ cost: Double, estimated: Bool) -> String {
        let prefix = estimated ? "~" : ""
        return "\(prefix)$\(String(format: "%.2f", max(0, cost)))"
    }
}
