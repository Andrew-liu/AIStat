import SwiftUI

struct CPUDetailView: View {
    let detail: CPUStatsDetail
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BackButton(title: "Codex Usage", action: onBack)
            HStack(alignment: .top, spacing: 10) {
                InfoCard(title: "CPU Usage", rows: [
                    ("user", percent(detail.userPercent)),
                    ("sys", percent(detail.systemPercent)),
                    ("idle", percent(detail.idlePercent))
                ], markers: [.providerAccent("blue"), .providerAccent("red"), .secondary.opacity(0.45)])
                InfoCard(title: "Load avg", rows: [
                    ("1m", decimal(detail.load1)),
                    ("5m", decimal(detail.load5)),
                    ("15m", decimal(detail.load15))
                ])
            }

            InfoCard(title: "CPU State", rows: [("Mode", detail.stateText)])
            InfoCard(title: "SoC", rows: [("Chip", detail.socName)])
            InfoCard(title: "System", rows: [("Health", detail.systemHealthText)])
            ProcessListCard(title: "Processes", processes: detail.topProcesses)
            InfoCard(title: "Uptime", rows: [("", detail.uptimeText)])
        }
    }
}

struct MemoryDetailView: View {
    let detail: MemoryStatsDetail
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BackButton(title: "Codex Usage", action: onBack)
            VStack(alignment: .leading, spacing: 10) {
                Text("Memory Usage")
                    .sectionTitle()
                HStack(spacing: 14) {
                    MemoryPieChart(detail: detail)
                        .frame(width: 96, height: 96)
                    InfoRows(rows: [
                        ("Wired", gb(detail.wiredGB)),
                        ("Active", gb(detail.activeGB)),
                        ("Compressed", gb(detail.compressedGB)),
                        ("Free", gb(detail.freeGB))
                    ], markers: [.providerAccent("red"), .providerAccent("blue"), .gray.opacity(0.82), .providerAccent("green")])
                }
            }
            .padding(10)
            .background(appCardBackground)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Memory Pressure")
                        .sectionTitle()
                    Spacer()
                    Text(percent(detail.memoryPressurePercent))
                        .valueText()
                }
                ProgressBar(value: detail.memoryPressurePercent, accent: .providerAccent("green"))
                    .frame(height: 4)
            }
            .padding(10)
            .background(appCardBackground)

            InfoCard(title: "Physical Memory", rows: [
                ("Physical Memory", detail.physicalMemoryText),
                ("Memory Used", detail.usedMemoryText),
                ("Cached Files", detail.cachedFilesText)
            ])
            ProcessListCard(title: "Processes", processes: detail.topProcesses)
            InfoCard(title: "Pages", rows: [
                ("Page Ins", detail.pageInsText),
                ("Page Outs", detail.pageOutsText),
                ("Swap Usage", detail.swapUsageText)
            ])
        }
    }
}

struct DiskDetailView: View {
    let detail: DiskStatsDetail
    let readSpeed: String
    let writeSpeed: String
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BackButton(title: "Codex Usage", action: onBack)
            HStack {
                Text("Volumes")
                    .sectionTitle()
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(readSpeed).foregroundStyle(Color.providerAccent("blue"))
                    Text(writeSpeed).foregroundStyle(Color.providerAccent("red"))
                }
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            }
            ForEach(detail.volumes) { volume in
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Label(volume.name, systemImage: "externaldrive.fill")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(Int(volume.usedPercent.rounded()))%")
                            .valueText()
                    }
                    ProgressBar(value: volume.usedPercent, accent: diskAccent(volume.usedPercent))
                        .frame(height: 4)
                    Text("\(volume.usedText) used  ·  \(volume.freeText) free")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(appCardBackground)
            }
        }
    }

    private func diskAccent(_ percent: Double) -> Color {
        percent > 90 ? .providerAccent("red") : (percent > 75 ? .providerAccent("orange") : .providerAccent("green"))
    }
}

struct BatteryDetailView: View {
    let detail: BatteryStatsDetail
    let batteryPercent: Double?
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BackButton(title: "Codex Usage", action: onBack)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(detail.stateText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(percent(batteryPercent))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                ProgressBar(value: batteryPercent, accent: .providerAccent("blue"))
                    .frame(height: 4)
                Text(detail.timeRemainingText)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(appCardBackground)

            InfoCard(title: "Health", rows: [
                ("Health", detail.healthPercent.map { "\(Int($0.rounded()))%" } ?? "--"),
                ("Condition", detail.conditionText),
                ("Cycle Count", detail.cycleCountText),
                ("Power Adapter", detail.powerAdapterText),
                ("Temperature", detail.temperatureText)
            ])
            InfoCard(title: "Power", rows: [("Time on AC", detail.timeOnACText)])
            InfoCard(title: "Capacity", rows: [
                ("Remaining Charge Capacity", detail.remainingCapacityText),
                ("Full Charge Capacity", detail.fullChargeCapacityText),
                ("Design Charge Capacity", detail.designChargeCapacityText)
            ])
        }
    }
}

struct MemoryPieChart: View {
    let detail: MemoryStatsDetail

    private var slices: [(value: Double, color: Color)] {
        [
            (detail.wiredGB ?? 0, .providerAccent("red")),
            (detail.activeGB ?? 0, .providerAccent("blue")),
            (detail.compressedGB ?? 0, .gray.opacity(0.82)),
            (detail.freeGB ?? 0, .providerAccent("green"))
        ]
    }

    private var total: Double {
        max(0.01, slices.map(\.value).reduce(0, +))
    }

    var body: some View {
        ZStack {
            ForEach(Array(slices.enumerated()), id: \.offset) { index, slice in
                PieSlice(
                    startAngle: startAngle(for: index),
                    endAngle: endAngle(for: index)
                )
                .fill(slice.color)
            }
            Circle()
                .fill(.background.opacity(0.72))
                .frame(width: 42, height: 42)
            Text(percent(detail.memoryPressurePercent))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .clipShape(Circle())
    }

    private func startAngle(for index: Int) -> Angle {
        let prior = slices.prefix(index).map(\.value).reduce(0, +)
        return .degrees(prior / total * 360 - 90)
    }

    private func endAngle(for index: Int) -> Angle {
        let current = slices.prefix(index + 1).map(\.value).reduce(0, +)
        return .degrees(current / total * 360 - 90)
    }
}

struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}
