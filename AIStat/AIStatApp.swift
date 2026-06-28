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

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(model)
                .environmentObject(systemStats)
                .environmentObject(awakeController)
                .environmentObject(settings)
                .onAppear { model.bind(settings: settings) }
                .onChange(of: settings.refreshInterval) { _, newValue in
                    model.restartPolling(interval: newValue)
                }
                .onChange(of: settings.disabledProviderIDs) { _, _ in
                    model.applyEnabledProviders()
                }
        } label: {
            MenuBarLabel(isKeepingAwake: awakeController.isKeepingAwake)
        }
        .menuBarExtraStyle(.window)
    }
}
