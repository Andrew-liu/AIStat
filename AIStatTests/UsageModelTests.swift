import XCTest
@testable import AIStat

/// Provider 数据模型、定价表、刷新间隔等纯逻辑测试。
final class UsageModelTests: XCTestCase {

    func testRefreshIntervalSeconds() {
        XCTAssertNil(RefreshInterval.manual.seconds)
        XCTAssertEqual(RefreshInterval.oneMinute.seconds, 60)
        XCTAssertEqual(RefreshInterval.twoMinutes.seconds, 120)
        XCTAssertEqual(RefreshInterval.fiveMinutes.seconds, 300)
        XCTAssertEqual(RefreshInterval.fifteenMinutes.seconds, 900)
    }

    func testRateLimitWindowRemaining() {
        let window = RateLimitWindow(id: "w", name: "5h", usedPercent: 30, resetsAt: nil, durationMinutes: 300)
        XCTAssertEqual(window.remainingPercent, 70, accuracy: 0.001)

        // 越界被夹断
        let over = RateLimitWindow(id: "w", name: "5h", usedPercent: 130, resetsAt: nil, durationMinutes: nil)
        XCTAssertEqual(over.remainingPercent, 0, accuracy: 0.001)
    }

    func testProviderUsageHasUsageData() {
        let empty = ProviderUsage(
            id: "codex", name: "Codex", symbolName: "terminal.fill", accentName: "purple",
            status: .unavailable, source: "", quotaWindows: [], cost: .empty, isConfigured: false
        )
        XCTAssertFalse(empty.hasUsageData)

        let withQuota = ProviderUsage(
            id: "codex", name: "Codex", symbolName: "terminal.fill", accentName: "purple",
            status: .operational, source: "",
            quotaWindows: [RateLimitWindow(id: "w", name: "5h", usedPercent: 10, resetsAt: nil, durationMinutes: 300)],
            cost: .empty, isConfigured: true
        )
        XCTAssertTrue(withQuota.hasUsageData)

        var cost = TokenCostSummary.empty
        cost.todayTokens = 1_000
        let withCost = ProviderUsage(
            id: "claude", name: "Claude", symbolName: "sparkles", accentName: "purple",
            status: .operational, source: "", quotaWindows: [], cost: cost, isConfigured: true
        )
        XCTAssertTrue(withCost.hasUsageData)
    }

    func testProviderDescriptorsRegistered() {
        let ids = UsageProviderRegistry.descriptors.map(\.id)
        XCTAssertTrue(ids.contains("codex"))
        XCTAssertTrue(ids.contains("claude"))
    }

    func testPricingTableSelectsByModel() {
        // Codex mini 比默认便宜
        XCTAssertLessThan(UsagePricingTable.codex("gpt-5-mini").input, UsagePricingTable.codex("gpt-5.4").input)
        // Claude opus 比 sonnet 贵
        XCTAssertGreaterThan(UsagePricingTable.claude("claude-opus-4").output, UsagePricingTable.claude("claude-sonnet-4").output)
        // haiku 最便宜
        XCTAssertLessThan(UsagePricingTable.claude("claude-haiku").input, UsagePricingTable.claude("claude-sonnet-4").input)
    }
}
