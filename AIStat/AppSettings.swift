import Foundation
import Combine
import ServiceManagement

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

/// 全局应用设置：刷新间隔、各 Provider 启用状态、开机启动。
///
/// 通过 `UserDefaults` 持久化；开机启动使用 `SMAppService`（macOS 13+）。
@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let refreshInterval = "settings.refreshInterval"
        static let disabledProviders = "settings.disabledProviders"
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

    init() {
        let storedInterval = defaults.string(forKey: Keys.refreshInterval)
            .flatMap(RefreshInterval.init(rawValue:)) ?? .fiveMinutes
        self.refreshInterval = storedInterval

        let storedDisabled = defaults.array(forKey: Keys.disabledProviders) as? [String] ?? []
        self.disabledProviderIDs = Set(storedDisabled)

        self.launchAtLogin = SMAppService.mainApp.status == .enabled
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
