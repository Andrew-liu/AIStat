//
//  AIStatApp.swift
//  AIStat
//
//  Created by asyncliu on 2026/6/14.
//

import SwiftUI

@main
struct AIStatApp: App {
    @StateObject private var model = CodexUsageModel()
    @StateObject private var systemStats = SystemStatsModel()
    @StateObject private var awakeController = AwakeController()
    @StateObject private var settings = AppSettings()
    @StateObject private var alertManager = UsageAlertManager()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(model)
                .environmentObject(systemStats)
                .environmentObject(awakeController)
                .environmentObject(settings)
                .tint(.providerAccent(settings.accent.accentName))
                .onAppear {
                    applyAppearance(settings.appearance)
                    model.bind(settings: settings)
                    // 用量更新后评估是否触发额度通知。
                    model.onProvidersUpdated = { providers in
                        alertManager.evaluate(providers: providers, threshold: settings.usageAlertThreshold)
                    }
                }
                .onChange(of: settings.appearance) { _, newValue in
                    applyAppearance(newValue)
                }
                .onChange(of: settings.language) { _, _ in
                    // 语言覆盖需重启 Bundle 才能加载新语言；切换后自动重启 App。
                    relaunchApp()
                }
                .onChange(of: settings.refreshInterval) { _, newValue in
                    model.restartPolling(interval: newValue)
                }
                .onChange(of: settings.disabledProviderIDs) { _, _ in
                    model.applyEnabledProviders()
                }
                .onChange(of: settings.usageAlertThreshold) { _, newValue in
                    // 阈值变化后按新档立即评估当前用量。
                    // 去重签名已含阈值档，不同档不会互相覆盖，无需清空历史记录。
                    alertManager.evaluate(providers: model.providers, threshold: newValue)
                }

        } label: {
            MenuBarLabel(
                isKeepingAwake: awakeController.isKeepingAwake,
                constrainedUsedPercent: settings.showUsageInMenuBar ? model.mostConstrainedWindow?.window.usedPercent : nil
            )
        }
        .menuBarExtraStyle(.window)
    }

    /// 重启 App：用 LaunchServices 重新启动自身，稍后退出当前实例（用于语言切换生效）。
    private func relaunchApp() {
        let appURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.activates = false

        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
            guard error == nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.terminate(nil)
            }
        }
    }

    /// 设置应用级外观（对菜单栏弹窗有效；`.preferredColorScheme` 对 MenuBarExtra 窗口不可靠）。
    private func applyAppearance(_ mode: AppearanceMode) {
        switch mode {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
