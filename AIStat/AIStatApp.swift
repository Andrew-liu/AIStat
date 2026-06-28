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

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(model)
                .environmentObject(systemStats)
                .environmentObject(awakeController)
        } label: {
            MenuBarLabel(isKeepingAwake: awakeController.isKeepingAwake)
        }
        .menuBarExtraStyle(.window)
    }
}
