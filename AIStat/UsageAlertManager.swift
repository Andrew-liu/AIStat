import Foundation
import Combine
@preconcurrency import UserNotifications

/// 额度临界通知管理器。
///
/// 在每次用量刷新后检查所有 Provider 的额度窗口，当某窗口的已用百分比达到设定阈值时，
/// 发送一条系统通知。同一窗口的同一重置周期只提醒一次（去重），避免重复打扰。
@MainActor
final class UsageAlertManager: ObservableObject {
    /// 已提醒过的窗口签名集合（provider + window + 周期 + 阈值档），用于去重。
    private var firedKeys: Set<String> = []
    /// 去重记录上限，避免长时间运行后随重置周期变化而无限增长。
    private let maxFiredKeys = 200

    /// 检查给定 Provider 列表，对达到阈值的额度窗口发送通知。
    /// - Parameters:
    ///   - providers: 最新的 Provider 用量列表。
    ///   - threshold: 触发阈值（已用百分比）；为 nil 时不发送。
    func evaluate(providers: [ProviderUsage], threshold: UsageAlertThreshold) {
        guard let limit = threshold.percent else { return }

        var pending: [(title: String, body: String, key: String)] = []
        for provider in providers {
            for window in provider.quotaWindows where window.usedPercent >= limit {
                let key = signature(providerID: provider.id, window: window, threshold: threshold)
                guard !firedKeys.contains(key) else { continue }
                firedKeys.insert(key)
                let used = Int(window.usedPercent.rounded())
                pending.append((
                    title: "\(provider.name) · \(window.name)",
                    body: alertBody(used: used, resetsAt: window.resetsAt),
                    key: key
                ))
            }
        }

        // 去重集合超限时整体清空（最坏情况下顶多重复提醒一轮，可接受）。
        if firedKeys.count > maxFiredKeys {
            firedKeys = Set(pending.map(\.key))
        }

        guard !pending.isEmpty else { return }
        ensureAuthorization { [weak self] granted in
            guard granted else {
                // 未授权时撤回去重标记，下次有机会再次尝试。
                Task { @MainActor in
                    for item in pending { self?.firedKeys.remove(item.key) }
                }
                return
            }
            Task { @MainActor in
                for item in pending {
                    self?.send(title: item.title, body: item.body)
                }
            }
        }
    }

    private func alertBody(used: Int, resetsAt: Date?) -> String {
        let usagePart = String(format: NSLocalizedString("alert.body.used", comment: ""), used)
        guard let resetsAt, resetsAt.timeIntervalSinceNow > 0 else { return usagePart }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let resetPart = formatter.localizedString(for: resetsAt, relativeTo: Date())
        let resetSentence = String(format: NSLocalizedString("alert.body.resets", comment: ""), resetPart)
        return "\(usagePart) \(resetSentence)"
    }

    private func signature(providerID: String, window: RateLimitWindow, threshold: UsageAlertThreshold) -> String {
        Self.signature(providerID: providerID, window: window, threshold: threshold)
    }

    /// 纯函数：生成去重签名（provider + 窗口名 + 重置周期 + 阈值档）。
    /// 同一窗口的同一重置周期、同一阈值档只会产生相同 key，用于「只提醒一次」。
    /// 抽成 `nonisolated static` 以便单元测试覆盖。
    nonisolated static func signature(
        providerID: String,
        window: RateLimitWindow,
        threshold: UsageAlertThreshold
    ) -> String {
        let period = window.resetsAt.map { String(Int($0.timeIntervalSince1970)) } ?? "no-reset"
        return "\(providerID)|\(window.name)|\(period)|\(threshold.rawValue)"
    }

    private func ensureAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                completion(true)
            case .denied:
                completion(false)
            default:
                // 在闭包内重新获取 center，避免捕获非 Sendable 的外部实例。
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    completion(granted)
                }
            }
        }
    }

    private func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
