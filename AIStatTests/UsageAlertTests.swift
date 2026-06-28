import XCTest
@testable import AIStat

/// v1.2.0 额度临界通知去重逻辑测试。
///
/// 验证 `UsageAlertManager.signature` 这一纯函数：相同输入生成相同 key（保证「只提醒一次」），
/// 不同 provider / 窗口 / 重置周期 / 阈值档则生成不同 key（避免误去重）。
final class UsageAlertTests: XCTestCase {

    private func window(name: String, resetsAt: Date?) -> RateLimitWindow {
        RateLimitWindow(id: name, name: name, usedPercent: 90, resetsAt: resetsAt, durationMinutes: nil)
    }

    func testSignatureIsStableForSameInput() {
        let reset = Date(timeIntervalSince1970: 1_000_000)
        let w = window(name: "Week", resetsAt: reset)
        let a = UsageAlertManager.signature(providerID: "codex", window: w, threshold: .ninety)
        let b = UsageAlertManager.signature(providerID: "codex", window: w, threshold: .ninety)
        XCTAssertEqual(a, b, "相同输入应生成相同签名，保证同一周期只提醒一次")
    }

    func testSignatureDiffersByProvider() {
        let w = window(name: "Week", resetsAt: nil)
        let codex = UsageAlertManager.signature(providerID: "codex", window: w, threshold: .ninety)
        let claude = UsageAlertManager.signature(providerID: "claude", window: w, threshold: .ninety)
        XCTAssertNotEqual(codex, claude)
    }

    func testSignatureDiffersByWindowName() {
        let session = UsageAlertManager.signature(providerID: "codex", window: window(name: "5h", resetsAt: nil), threshold: .ninety)
        let week = UsageAlertManager.signature(providerID: "codex", window: window(name: "Week", resetsAt: nil), threshold: .ninety)
        XCTAssertNotEqual(session, week)
    }

    func testSignatureDiffersByResetPeriod() {
        // 不同重置周期（resetsAt）应视为不同周期，可再次提醒。
        let p1 = UsageAlertManager.signature(providerID: "codex", window: window(name: "Week", resetsAt: Date(timeIntervalSince1970: 1_000)), threshold: .ninety)
        let p2 = UsageAlertManager.signature(providerID: "codex", window: window(name: "Week", resetsAt: Date(timeIntervalSince1970: 2_000)), threshold: .ninety)
        XCTAssertNotEqual(p1, p2)
    }

    func testSignatureDiffersByThreshold() {
        // 不同阈值档天然隔离，调高阈值不会与旧档撞 key（避免重复提醒）。
        let w = window(name: "Week", resetsAt: nil)
        let eighty = UsageAlertManager.signature(providerID: "codex", window: w, threshold: .eighty)
        let ninety = UsageAlertManager.signature(providerID: "codex", window: w, threshold: .ninety)
        XCTAssertNotEqual(eighty, ninety)
    }

    func testSignatureNoResetUsesStablePlaceholder() {
        // 无 resetsAt 时用固定占位 "no-reset"，保证无重置时间的窗口也能稳定去重。
        let a = UsageAlertManager.signature(providerID: "codex", window: window(name: "Week", resetsAt: nil), threshold: .ninety)
        let b = UsageAlertManager.signature(providerID: "codex", window: window(name: "Week", resetsAt: nil), threshold: .ninety)
        XCTAssertEqual(a, b)
        XCTAssertTrue(a.contains("no-reset"))
    }
}
