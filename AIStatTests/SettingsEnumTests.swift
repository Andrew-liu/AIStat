import XCTest
@testable import AIStat

/// v1.2.0 设置相关枚举的纯逻辑测试（语言 / 外观 / 强调色 / 通知阈值）。
final class SettingsEnumTests: XCTestCase {

    func testAppLanguageLocaleCode() {
        XCTAssertNil(AppLanguage.system.localeCode)
        XCTAssertEqual(AppLanguage.english.localeCode, "en")
        XCTAssertEqual(AppLanguage.chinese.localeCode, "zh-Hans")
    }

    func testAppLanguageRoundTrip() {
        for lang in AppLanguage.allCases {
            XCTAssertEqual(AppLanguage(rawValue: lang.rawValue), lang)
            XCTAssertFalse(lang.titleKey.isEmpty)
        }
    }

    func testAppearanceModeCases() {
        // 三档外观齐全且 titleKey 非空。
        XCTAssertEqual(Set(AppearanceMode.allCases.map(\.rawValue)), ["system", "light", "dark"])
        for mode in AppearanceMode.allCases {
            XCTAssertFalse(mode.titleKey.isEmpty)
        }
    }

    func testAccentPresetMapsToColorName() {
        // 每个强调色预设的 accentName 与 rawValue 一致，供 Color.providerAccent 使用。
        for preset in AccentPreset.allCases {
            XCTAssertEqual(preset.accentName, preset.rawValue)
        }
        XCTAssertTrue(AccentPreset.allCases.map(\.id).contains("purple"))
    }

    func testUsageAlertThresholdPercent() {
        XCTAssertNil(UsageAlertThreshold.off.percent)
        XCTAssertEqual(UsageAlertThreshold.seventy.percent, 70)
        XCTAssertEqual(UsageAlertThreshold.eighty.percent, 80)
        XCTAssertEqual(UsageAlertThreshold.ninety.percent, 90)
        XCTAssertEqual(UsageAlertThreshold.ninetyFive.percent, 95)
    }

    func testUsageAlertThresholdMonotonic() {
        // 非 off 档位的阈值应严格递增。
        let values = UsageAlertThreshold.allCases.compactMap(\.percent)
        XCTAssertEqual(values, values.sorted())
        XCTAssertEqual(Set(values).count, values.count)
    }
}
