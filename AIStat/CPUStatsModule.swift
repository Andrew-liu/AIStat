import Foundation

final class CPUStatsModule: @unchecked Sendable {
    private let runner: SystemCommandRunner

    init(runner: SystemCommandRunner) {
        self.runner = runner
    }

    nonisolated func readDetail() -> CPUStatsDetail {
        let topOutput = runner.run("/usr/bin/top", arguments: ["-l", "1", "-n", "0"])
        let cpuParts = parseCPUUsage(from: topOutput)
        let load = parseLoadAverage(from: runner.run("/usr/sbin/sysctl", arguments: ["-n", "vm.loadavg"]))
        let cpuPercent = cpuParts.map { SystemStatsFormatter.clamp($0.user + $0.system) }
        let topProcesses = runner.readProcesses(arguments: ["-arcwwwxo", "comm=,pcpu=,rss="], valueIndex: 1, limit: 5).map { process in
            SystemProcessSummary(
                id: "cpu-\(process.name)-\(process.index)",
                name: process.name,
                valueText: String(format: "%.1f%%", process.cpu),
                detailText: SystemStatsFormatter.formatBytes(Double(process.rssKB) * 1024)
            )
        }

        return CPUStatsDetail(
            userPercent: cpuParts?.user,
            systemPercent: cpuParts?.system,
            idlePercent: cpuParts?.idle,
            load1: load.0,
            load5: load.1,
            load15: load.2,
            stateText: cpuPercent.map { $0 > 85 ? "Heavy" : ($0 > 55 ? "Active" : "Balanced") } ?? "Balanced",
            gpuPercent: nil,
            gpuMemoryUsedText: "--",
            gpuMemoryTotalText: "--",
            socName: readSoCName(),
            systemHealthText: cpuPercent.map { $0 > 90 ? "Busy" : "Nominal" } ?? "Nominal",
            uptimeText: readUptimeText(),
            topProcesses: topProcesses
        )
    }

    nonisolated func readPercent(from detail: CPUStatsDetail) -> Double? {
        guard let user = detail.userPercent, let system = detail.systemPercent else { return nil }
        return SystemStatsFormatter.clamp(user + system)
    }

    private nonisolated func parseCPUUsage(from text: String?) -> (user: Double, system: Double, idle: Double)? {
        guard let line = text?.components(separatedBy: .newlines).first(where: { $0.contains("CPU usage:") }) else { return nil }
        let numbers = line.regexMatches(for: #"([0-9]+(?:\.[0-9]+)?)%"#).compactMap(Double.init)
        guard numbers.count >= 3 else { return nil }
        return (numbers[0], numbers[1], numbers[2])
    }

    private nonisolated func parseLoadAverage(from text: String?) -> (Double?, Double?, Double?) {
        let values = text?.regexMatches(for: #"[0-9]+(?:\.[0-9]+)?"#).compactMap(Double.init) ?? []
        return (
            values.indices.contains(0) ? values[0] : nil,
            values.indices.contains(1) ? values[1] : nil,
            values.indices.contains(2) ? values[2] : nil
        )
    }

    private nonisolated func readSoCName() -> String {
        let value = runner.run("/usr/sbin/sysctl", arguments: ["-n", "machdep.cpu.brand_string"])?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value! : "Apple Silicon"
    }

    private nonisolated func readUptimeText() -> String {
        guard let output = runner.run("/usr/sbin/sysctl", arguments: ["-n", "kern.boottime"]),
              let seconds = output.regexMatches(for: #"sec = ([0-9]+)"#).first,
              let bootSeconds = TimeInterval(seconds) else { return "--" }
        let interval = Date().timeIntervalSince1970 - bootSeconds
        let days = Int(interval / 86_400)
        let hours = Int(interval.truncatingRemainder(dividingBy: 86_400) / 3_600)
        if days > 0 { return "\(days) days, \(hours) hours" }
        return "\(hours) hours"
    }
}
