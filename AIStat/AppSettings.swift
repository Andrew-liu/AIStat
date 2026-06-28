import Foundation
import Combine
import ServiceManagement
import SwiftUI

/// AI 用量自动刷新间隔。
enum RefreshInterval: String, CaseIterable, Identifiable, Sendable {
    case manual
    case oneMinute
    case twoMinutes
    case fiveMinutes
    case fifteenMinutes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manual: return "Manual"
        case .oneMinute: return "1m"
        case .twoMinutes: return "2m"
        case .fiveMinutes: return "5m"
        case .fifteenMinutes: return "15m"
        }
    }

    /// 轮询间隔秒数；`manual` 表示不自动刷新。
    var seconds: TimeInterval? {
        switch self {
        case .manual: return nil
        case .oneMinute: return 60
        case .twoMinutes: return 120
        case .fiveMinutes: return 300
        case .fifteenMinutes: return 900
        }
    }
}

/// 应用界面语言。
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english
    case chinese

    var id: String { rawValue }

    /// 本地化标题键。
    var titleKey: String {
        switch self {
        case .system: return "language.system"
        case .english: return "language.english"
        case .chinese: return "language.chinese"
        }
    }

    /// 对应写入 `AppleLanguages` 的语言代码；`system` 为 nil（移除覆盖、跟随系统）。
    var localeCode: String? {
        switch self {
        case .system: return nil
        case .english: return "en"
        case .chinese: return "zh-Hans"
        }
    }
}

/// 应用外观模式。
enum AppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// 用于本地化键，标题在 UI 层通过 `LocalizedStringKey` 解析。
    var titleKey: String {
        switch self {
        case .system: return "appearance.system"
        case .light: return "appearance.light"
        case .dark: return "appearance.dark"
        }
    }
}

/// 可选的强调色预设。
enum AccentPreset: String, CaseIterable, Identifiable, Sendable {
    case purple
    case blue
    case green
    case orange
    case red
    case pink

    var id: String { rawValue }

    /// 与 `Color.providerAccent(_:)` 共用的颜色名。
    var accentName: String { rawValue }
}

/// 额度临界通知阈值（达到该已用百分比时提醒）。
enum UsageAlertThreshold: String, CaseIterable, Identifiable, Sendable {
    case off
    case seventy
    case eighty
    case ninety
    case ninetyFive

    var id: String { rawValue }

    /// 触发阈值（已用百分比）；`off` 表示关闭通知。
    var percent: Double? {
        switch self {
        case .off: return nil
        case .seventy: return 70
        case .eighty: return 80
        case .ninety: return 90
        case .ninetyFive: return 95
        }
    }

    var title: String {
        switch self {
        case .off: return "Off"
        case .seventy: return "70%"
        case .eighty: return "80%"
        case .ninety: return "90%"
        case .ninetyFive: return "95%"
        }
    }
}

/// 全局应用设置：刷新间隔、各 Provider 启用状态、开机启动。
///
/// 通过 `UserDefaults` 持久化；开机启动使用 `SMAppService`（macOS 13+）。
@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let refreshInterval = "settings.refreshInterval"
        static let disabledProviders = "settings.disabledProviders"
        static let appearance = "settings.appearance"
        static let accent = "settings.accent"
        static let usageAlertThreshold = "settings.usageAlertThreshold"
        static let showUsageInMenuBar = "settings.showUsageInMenuBar"
        static let language = "settings.language"
        static let appleLanguages = "AppleLanguages"
    }

    private let defaults = UserDefaults.standard

    @Published var refreshInterval: RefreshInterval {
        didSet {
            guard refreshInterval != oldValue else { return }
            defaults.set(refreshInterval.rawValue, forKey: Keys.refreshInterval)
        }
    }

    /// 被用户禁用的 Provider id 集合。
    @Published private(set) var disabledProviderIDs: Set<String> {
        didSet {
            guard disabledProviderIDs != oldValue else { return }
            defaults.set(Array(disabledProviderIDs), forKey: Keys.disabledProviders)
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            applyLaunchAtLogin(launchAtLogin)
        }
    }

    /// 外观模式（浅色/深色/跟随系统）。
    @Published var appearance: AppearanceMode {
        didSet {
            guard appearance != oldValue else { return }
            defaults.set(appearance.rawValue, forKey: Keys.appearance)
        }
    }

    /// 全局强调色预设。
    @Published var accent: AccentPreset {
        didSet {
            guard accent != oldValue else { return }
            defaults.set(accent.rawValue, forKey: Keys.accent)
        }
    }

    /// 额度临界通知阈值。
    @Published var usageAlertThreshold: UsageAlertThreshold {
        didSet {
            guard usageAlertThreshold != oldValue else { return }
            defaults.set(usageAlertThreshold.rawValue, forKey: Keys.usageAlertThreshold)
        }
    }

    /// 是否在菜单栏显示用量信息（仅在用量紧张时）。
    @Published var showUsageInMenuBar: Bool {
        didSet {
            guard showUsageInMenuBar != oldValue else { return }
            defaults.set(showUsageInMenuBar, forKey: Keys.showUsageInMenuBar)
        }
    }

    /// 界面语言（覆盖系统语言，需重启生效）。
    @Published var language: AppLanguage {
        didSet {
            guard language != oldValue else { return }
            defaults.set(language.rawValue, forKey: Keys.language)
            applyLanguage(language)
        }
    }

    init() {
        let storedInterval = defaults.string(forKey: Keys.refreshInterval)
            .flatMap(RefreshInterval.init(rawValue:)) ?? .fiveMinutes
        self.refreshInterval = storedInterval

        let storedDisabled = defaults.array(forKey: Keys.disabledProviders) as? [String] ?? []
        self.disabledProviderIDs = Set(storedDisabled)

        self.launchAtLogin = SMAppService.mainApp.status == .enabled

        self.appearance = defaults.string(forKey: Keys.appearance)
            .flatMap(AppearanceMode.init(rawValue:)) ?? .system
        self.accent = defaults.string(forKey: Keys.accent)
            .flatMap(AccentPreset.init(rawValue:)) ?? .purple
        self.usageAlertThreshold = defaults.string(forKey: Keys.usageAlertThreshold)
            .flatMap(UsageAlertThreshold.init(rawValue:)) ?? .ninety
        // 默认开启菜单栏用量提示；首次安装时 object(forKey:) 为 nil。
        self.showUsageInMenuBar = defaults.object(forKey: Keys.showUsageInMenuBar) as? Bool ?? true

        self.language = defaults.string(forKey: Keys.language)
            .flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    func isProviderEnabled(_ id: String) -> Bool {
        !disabledProviderIDs.contains(id)
    }

    func setProvider(_ id: String, enabled: Bool) {
        if enabled {
            disabledProviderIDs.remove(id)
        } else {
            disabledProviderIDs.insert(id)
        }
    }

    /// 应用语言覆盖：写入/移除 `AppleLanguages`。需重启 App 生效。
    private func applyLanguage(_ language: AppLanguage) {
        if let code = language.localeCode {
            defaults.set([code], forKey: Keys.appleLanguages)
        } else {
            // 跟随系统：移除覆盖。
            defaults.removeObject(forKey: Keys.appleLanguages)
        }
        // 语言切换后会立即重启，主动同步可避免新实例读到旧语言设置。
        defaults.synchronize()
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            // 注册失败时回退到真实状态，避免开关与系统状态不一致。
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
