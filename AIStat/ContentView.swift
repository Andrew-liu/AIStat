//
//  ContentView.swift
//  AIStat
//
//  Created by asyncliu on 2026/6/14.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: CodexUsageModel
    @EnvironmentObject private var systemStats: SystemStatsModel
    @EnvironmentObject private var awakeController: AwakeController
    @State private var page: DashboardPage = .codex

    private var stats: SystemStatsSummary { systemStats.summary }
    private var providers: [ProviderUsage] { model.providers }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            SystemMetricStripView(stats: stats, page: $page)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            Divider()

            ScrollView(showsIndicators: true) {
                VStack(spacing: 10) {
                    pageContent
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            VStack(spacing: 8) {
                AwakePanelView(awakeController: awakeController)
                footer
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: 372, height: 590, alignment: .top)
        .background(panelBackground)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.providerAccent("purple"))
            Text("AIStat")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var pageContent: some View {
        switch page {
        case .codex:
            codexDashboard
        case .cpu:
            CPUDetailView(detail: stats.cpuDetail, onBack: { page = .codex })
        case .memory:
            MemoryDetailView(detail: stats.memoryDetail, onBack: { page = .codex })
        case .disk:
            DiskDetailView(
                detail: stats.diskDetail,
                readSpeed: stats.diskReadSpeedText,
                writeSpeed: stats.diskWriteSpeedText,
                onBack: { page = .codex }
            )
        case .battery:
            BatteryDetailView(detail: stats.batteryDetail, batteryPercent: stats.batteryPercent, onBack: { page = .codex })
        }
    }

    private var codexDashboard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Providers", subtitle: "")

            VStack(spacing: 8) {
                ForEach(providers) { provider in
                    ProviderUsageCard(provider: provider)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text(model.updatedAt?.formatted(date: .omitted, time: .shortened) ?? "Not updated")
                .lineLimit(1)
            Spacer()
            Button {
                model.refresh()
                systemStats.refresh()
            } label: {
                Label("Refresh", systemImage: model.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .help("Refresh")
            .disabled(model.isRefreshing)

            Button {
                model.quit()
            } label: {
                Label("Quit", systemImage: "power")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .help("Quit")
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 2)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.regularMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.separator.opacity(0.45), lineWidth: 0.5)
            }
    }
}

struct MenuBarLabel: View {
    let isKeepingAwake: Bool

    var body: some View {
        Image(systemName: isKeepingAwake ? "cup.and.saucer.fill" : "moon.zzz.fill")
            .font(.system(size: 13, weight: .semibold))
    }
}
