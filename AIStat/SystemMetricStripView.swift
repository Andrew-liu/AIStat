import SwiftUI

struct SystemMetricStripView: View {
    let stats: SystemStatsSummary
    @Binding var page: DashboardPage

    var body: some View {
        HStack(spacing: 8) {
            MetricButton(title: "CPU", icon: "cpu", value: stats.cpuPercent, accent: .providerAccent("blue"), isSelected: page == .cpu) {
                page = .cpu
            }
            MetricButton(title: "MEM", icon: "memorychip", value: stats.memoryPercent, accent: .providerAccent("purple"), isSelected: page == .memory) {
                page = .memory
            }
            MetricButton(title: "DISK", icon: "internaldrive", value: stats.diskPercent, accent: .providerAccent("orange"), isSelected: page == .disk) {
                page = .disk
            }
            MetricButton(title: "BAT", icon: batterySymbol(for: stats.batteryPercent), value: stats.batteryPercent, accent: .providerAccent("green"), isSelected: page == .battery) {
                page = .battery
            }
        }
    }
}

private struct MetricButton: View {
    let title: String
    let icon: String
    let value: Double?
    let accent: Color
    let isSelected: Bool
    let action: () -> Void

    private var displayValue: Double { max(0, min(100, value ?? 0)) }
    private var iconColor: Color { isSelected ? accent : .secondary }
    private var fillColor: Color { isSelected ? accent.opacity(0.12) : Color.secondary.opacity(0.07) }
    private var strokeColor: Color { isSelected ? accent.opacity(0.35) : Color.secondary.opacity(0.16) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                ring
                labels
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(fillColor))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(strokeColor, lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) \(percentText)")
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.18), lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(displayValue / 100))
                .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(iconColor)
        }
        .frame(width: 28, height: 28)
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(percentText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            Text(title)
                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var percentText: String {
        guard value != nil else { return "--" }
        return "\(Int(displayValue.rounded()))%"
    }
}
