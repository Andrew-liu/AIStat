import SwiftUI

struct ProviderUsageCard: View {
    let provider: AIUsageProvider

    private var accent: Color { .providerAccent(provider.accentName) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            sectionTitle("Cost")
            costSummary
            Divider()
            sectionTitle("Quota")
            quotaSection
        }
        .padding(12)
        .background(appCardBackground)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ProviderIcon(symbol: provider.symbolName, accent: accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name)
                    .font(.system(size: 17, weight: .semibold))
                Text(provider.note)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
            StatusBadge(status: provider.status)
        }
    }

    private var costSummary: some View {
        HStack(spacing: 10) {
            CostColumn(title: "Today", tokens: provider.todayTokensText, cost: provider.todayCostText)
            CostColumn(title: "This Month", tokens: provider.monthTokensText, cost: provider.monthCostText)
        }
    }

    @ViewBuilder
    private var quotaSection: some View {
        if provider.metrics.isEmpty {
            QuotaUnavailableRow(provider: provider)
        } else {
            VStack(spacing: 12) {
                ForEach(provider.metrics) { metric in
                    QuotaRow(metric: metric, accent: .providerAccent(metric.accentName))
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

private struct CostColumn: View {
    let title: String
    let tokens: String
    let cost: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(tokens)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(cost)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StatusBadge: View {
    let status: AIProviderStatus

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.12)))
    }

    private var title: String {
        switch status {
        case .operational: return "Connected"
        case .stale: return "Available"
        case .limited: return "Desktop only"
        case .unavailable: return "Not configured"
        }
    }

    private var color: Color {
        switch status {
        case .operational: return .providerAccent("green")
        case .stale: return .providerAccent("orange")
        case .limited: return .providerAccent("orange")
        case .unavailable: return .secondary.opacity(0.75)
        }
    }
}

private struct QuotaRow: View {
    let metric: AIUsageMetric
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(metric.title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(metric.usedText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent)
            }

            ProgressBar(value: metric.percentUsed, accent: accent)
                .frame(height: 6)

            HStack {
                Text(metric.remainingText)
                Spacer()
                Text(metric.resetText)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .help(metric.resetText)
    }
}

private struct QuotaUnavailableRow: View {
    let provider: AIUsageProvider

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.badge.questionmark")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.id == "codex" || provider.id == "claude" ? "Quota refreshing" : "Quota unavailable")
                    .font(.system(size: 12.5, weight: .semibold))
                Text(provider.authSource)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
        }
    }
}
