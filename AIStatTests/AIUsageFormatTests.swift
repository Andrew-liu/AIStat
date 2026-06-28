import XCTest
@testable import AIStat

/// 展示格式化纯逻辑测试（tokens / cost / percent / resetText / accentName）。
final class AIUsageFormatTests: XCTestCase {

    func testTokensFormatting() {
        XCTAssertEqual(AIUsageFormat.tokens(0), "0 tokens")
        XCTAssertEqual(AIUsageFormat.tokens(500), "500 tokens")
        XCTAssertEqual(AIUsageFormat.tokens(1_500), "1.5K tokens")
        XCTAssertEqual(AIUsageFormat.tokens(2_500_000), "2.50M tokens")
    }

    func testCostFormatting() {
        XCTAssertEqual(AIUsageFormat.cost(0, estimated: false), "$0.00")
        XCTAssertEqual(AIUsageFormat.cost(12.5, estimated: false), "$12.50")
        XCTAssertEqual(AIUsageFormat.cost(12.5, estimated: true), "~$12.50")
        // 负数被夹到 0
        XCTAssertEqual(AIUsageFormat.cost(-3, estimated: false), "$0.00")
    }

    func testPercentFormatting() {
        XCTAssertEqual(AIUsageFormat.percent(nil), "--")
        XCTAssertEqual(AIUsageFormat.percent(42.4, suffix: " used"), "42% used")
        XCTAssertEqual(AIUsageFormat.percent(42.6, suffix: " used"), "43% used")
        // 越界被夹到 0~100
        XCTAssertEqual(AIUsageFormat.percent(150), "100%")
        XCTAssertEqual(AIUsageFormat.percent(-5), "0%")
    }

    func testAccentNameMapping() {
        XCTAssertEqual(AIUsageFormat.accentName(for: "5h"), "orange")
        XCTAssertEqual(AIUsageFormat.accentName(for: "Session"), "orange")
        XCTAssertEqual(AIUsageFormat.accentName(for: "Week"), "purple")
        XCTAssertEqual(AIUsageFormat.accentName(for: "30d"), "green")
        XCTAssertEqual(AIUsageFormat.accentName(for: "Opus"), "red")
        XCTAssertEqual(AIUsageFormat.accentName(for: "Sonnet"), "blue")
        // 注意：名称含 "week" 时 week 优先级高于 opus/sonnet，故归为 purple。
        XCTAssertEqual(AIUsageFormat.accentName(for: "Opus Week"), "purple")
        XCTAssertEqual(AIUsageFormat.accentName(for: "Sonnet Week"), "purple")
    }

    func testResetTextEdgeCases() {
        XCTAssertEqual(AIUsageFormat.resetText(nil), "reset unknown")
        XCTAssertEqual(AIUsageFormat.resetText(Date(timeIntervalSinceNow: -100)), "reset passed")
        XCTAssertTrue(AIUsageFormat.resetText(Date(timeIntervalSinceNow: 3 * 86_400 + 3_600)).contains("3d"))
        XCTAssertTrue(AIUsageFormat.resetText(Date(timeIntervalSinceNow: 2 * 3_600 + 600)).hasPrefix("resets in 2h"))
    }
}
