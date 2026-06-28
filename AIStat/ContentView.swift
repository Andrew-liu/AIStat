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
    @EnvironmentObject private var settings: AppSettings
    @State private var page: DashboardPage = .codex

    /// 当前品牌强调色（跟随设置）。
    private var accent: Color { .providerAccent(settings.accent.accentName) }

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
                AwakePanelView(awakeController: awakeController, accent: accent)
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
                .foregroundStyle(accent)
            Text(verbatim: "AIStat")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Button {
                page = (page == .settings) ? .codex : .settings
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(page == .settings ? accent : .secondary)
            }
            .buttonStyle(.plain)
            .help(Text("settings.title"))
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
        case .settings:
            SettingsView(onBack: { page = .codex })
        }
    }

    private var codexDashboard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "providers.title", subtitle: "")

            VStack(spacing: 8) {
                ForEach(providers) { provider in
                    ProviderUsageCard(provider: provider)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text(model.updatedAt?.formatted(date: .omitted, time: .shortened) ?? NSLocalizedString("footer.notUpdated", comment: ""))
                .lineLimit(1)
            Spacer()
            Button {
                model.refresh()
                systemStats.refresh()
            } label: {
                Label("action.refresh", systemImage: model.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .help(Text("action.refresh"))
            .disabled(model.isRefreshing)

            Button {
                model.quit()
            } label: {
                Label("action.quit", systemImage: "power")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .help(Text("action.quit"))
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
    /// 最紧张额度的已用百分比（nil 表示无数据或未开启显示）。
    var constrainedUsedPercent: Double? = nil

    /// 用量紧张的阈值：已用达到该比例时才在菜单栏显示百分比。
    private let busyThreshold: Double = 70

    private var showsUsage: Bool {
        guard let used = constrainedUsedPercent else { return false }
        return used >= busyThreshold
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: isKeepingAwake ? "cup.and.saucer.fill" : "moon.zzz.fill")
                .font(.system(size: 13, weight: .semibold))
            if showsUsage, let used = constrainedUsedPercent {
                Text("\(Int(used.rounded()))%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
        }
    }
}
