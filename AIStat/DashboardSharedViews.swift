import SwiftUI

struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            if !subtitle.isEmpty {
                Spacer()
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }
}

struct BackButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "chevron.left")
                Text(title)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}

struct ProviderIcon: View {
    let symbol: String
    let accent: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(accent.opacity(0.13))
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accent)
        }
        .frame(width: 28, height: 28)
    }
}

struct StatusPill: View {
    let status: AIProviderStatus

    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 6, height: 6)
            .help(status.rawValue)
    }

    private var statusColor: Color {
        switch status {
        case .operational: return .providerAccent("green")
        case .stale: return .providerAccent("orange")
        case .limited: return .providerAccent("orange")
        case .unavailable: return .secondary.opacity(0.55)
        }
    }
}

struct ProgressBar: View {
    let value: Double?
    let accent: Color

    private var clamped: Double { max(0, min(100, value ?? 0)) }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.secondary.opacity(0.13))
                Capsule()
                    .fill(accent.gradient)
                    .frame(width: max(3, proxy.size.width * CGFloat(clamped / 100)))
            }
        }
    }
}

struct InfoCard: View {
    let title: String
    let rows: [(String, String)]
    var markers: [Color] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).sectionTitle()
            InfoRows(rows: rows, markers: markers)
        }
        .padding(10)
        .background(appCardBackground)
    }
}

struct InfoRows: View {
    let rows: [(String, String)]
    var markers: [Color] = []

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 7) {
                    if markers.indices.contains(index) {
                        Circle()
                            .fill(markers[index])
                            .frame(width: 6, height: 6)
                    }
                    Text(row.0)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text(row.1)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }
        }
    }
}

struct ProcessListCard: View {
    let title: String
    let processes: [SystemProcessSummary]

    var body: some View {
        InfoCard(title: title, rows: processes.isEmpty ? [("No data", "--")] : processes.map { ($0.name, $0.valueText) })
    }
}
