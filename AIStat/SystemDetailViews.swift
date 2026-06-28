import SwiftUI

struct CPUDetailView: View {
    let detail: CPUStatsDetail
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BackButton(title: "nav.back", action: onBack)
            HStack(alignment: .top, spacing: 10) {
                InfoCard(title: NSLocalizedString("cpu.usage", comment: ""), rows: [
                    (NSLocalizedString("cpu.user", comment: ""), percent(detail.userPercent)),
                    (NSLocalizedString("cpu.sys", comment: ""), percent(detail.systemPercent)),
                    (NSLocalizedString("cpu.idle", comment: ""), percent(detail.idlePercent))
                ], markers: [.providerAccent("blue"), .providerAccent("red"), .secondary.opacity(0.45)])
                InfoCard(title: NSLocalizedString("cpu.loadAvg", comment: ""), rows: [
                    ("1m", decimal(detail.load1)),
                    ("5m", decimal(detail.load5)),
                    ("15m", decimal(detail.load15))
                ])
            }

            InfoCard(title: NSLocalizedString("cpu.state", comment: ""), rows: [(NSLocalizedString("cpu.mode", comment: ""), detail.stateText)])
            InfoCard(title: NSLocalizedString("cpu.soc", comment: ""), rows: [(NSLocalizedString("cpu.chip", comment: ""), detail.socName)])
            InfoCard(title: NSLocalizedString("cpu.system", comment: ""), rows: [(NSLocalizedString("cpu.health", comment: ""), detail.systemHealthText)])
            ProcessListCard(title: NSLocalizedString("cpu.processes", comment: ""), processes: detail.topProcesses)
            InfoCard(title: NSLocalizedString("cpu.uptime", comment: ""), rows: [("", detail.uptimeText)])
        }
    }
}

struct MemoryDetailView: View {
    let detail: MemoryStatsDetail
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BackButton(title: "nav.back", action: onBack)
            VStack(alignment: .leading, spacing: 10) {
                Text("mem.usage")
                    .sectionTitle()
                HStack(spacing: 14) {
                    MemoryPieChart(detail: detail)
                        .frame(width: 96, height: 96)
                    InfoRows(rows: [
                        (NSLocalizedString("mem.wired", comment: ""), gb(detail.wiredGB)),
                        (NSLocalizedString("mem.active", comment: ""), gb(detail.activeGB)),
                        (NSLocalizedString("mem.compressed", comment: ""), gb(detail.compressedGB)),
                        (NSLocalizedString("mem.free", comment: ""), gb(detail.freeGB))
                    ], markers: [.providerAccent("red"), .providerAccent("blue"), .gray.opacity(0.82), .providerAccent("green")])
                }
            }
            .padding(10)
            .background(appCardBackground)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("mem.pressure")
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

            InfoCard(title: NSLocalizedString("mem.physical", comment: ""), rows: [
                (NSLocalizedString("mem.physicalMemory", comment: ""), detail.physicalMemoryText),
                (NSLocalizedString("mem.used", comment: ""), detail.usedMemoryText),
                (NSLocalizedString("mem.cachedFiles", comment: ""), detail.cachedFilesText)
            ])
            ProcessListCard(title: NSLocalizedString("cpu.processes", comment: ""), processes: detail.topProcesses)
            InfoCard(title: NSLocalizedString("mem.pages", comment: ""), rows: [
                (NSLocalizedString("mem.pageIns", comment: ""), detail.pageInsText),
                (NSLocalizedString("mem.pageOuts", comment: ""), detail.pageOutsText),
                (NSLocalizedString("mem.swap", comment: ""), detail.swapUsageText)
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
            BackButton(title: "nav.back", action: onBack)
            HStack {
                Text("disk.volumes")
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
                    Text("\(volume.usedText) \(NSLocalizedString("disk.used", comment: ""))  ·  \(volume.freeText) \(NSLocalizedString("disk.free", comment: ""))")
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

    /// 充放电状态对应的色标：充电=绿、外接=蓝、放电/未知=橙。
    /// 基于语言无关的 `chargeState`，避免依赖已本地化的显示文本。
    private var stateColor: Color {
        switch detail.chargeState {
        case .charging: return .providerAccent("green")
        case .connected: return .providerAccent("blue")
        case .discharging, .unknown: return .providerAccent("orange")
        }
    }

    /// 健康度对应的颜色：≥80% 绿、≥50% 橙、否则红。
    private var healthColor: Color {
        guard let health = detail.healthPercent else { return .secondary }
        switch health {
        case 80...: return .providerAccent("green")
        case 50..<80: return .providerAccent("orange")
        default: return .providerAccent("red")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BackButton(title: LocalizedStringKey("nav.back"), action: onBack)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(stateColor)
                        .frame(width: 7, height: 7)
                    Text(detail.stateText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(percent(batteryPercent))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                ProgressBar(value: batteryPercent, accent: stateColor)
                    .frame(height: 4)
                Text(detail.timeRemainingText)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(appCardBackground)

            batteryHealthCard

            InfoCard(title: NSLocalizedString("battery.power", comment: ""), rows: [(NSLocalizedString("battery.timeOnAC", comment: ""), detail.timeOnACText)])
            InfoCard(title: NSLocalizedString("battery.capacity", comment: ""), rows: [
                (NSLocalizedString("battery.remainingCapacity", comment: ""), detail.remainingCapacityText),
                (NSLocalizedString("battery.fullCapacity", comment: ""), detail.fullChargeCapacityText),
                (NSLocalizedString("battery.designCapacity", comment: ""), detail.designChargeCapacityText)
            ])
        }
    }

    /// 增强版健康卡片：健康度进度条 + 关键指标行。
    private var batteryHealthCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("battery.health", comment: "")).sectionTitle()

            // 健康度进度条（有数据时）。
            if let health = detail.healthPercent {
                HStack(spacing: 7) {
                    Text(NSLocalizedString("battery.healthLabel", comment: ""))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(health.rounded()))%")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(healthColor)
                }
                ProgressBar(value: health, accent: healthColor)
                    .frame(height: 4)
            }

            InfoRows(rows: [
                (NSLocalizedString("battery.condition", comment: ""), detail.conditionText),
                (NSLocalizedString("battery.cycleCount", comment: ""), detail.cycleCountText),
                (NSLocalizedString("battery.powerAdapter", comment: ""), detail.powerAdapterText),
                (NSLocalizedString("battery.temperature", comment: ""), detail.temperatureText)
            ])
        }
        .padding(10)
        .background(appCardBackground)
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
