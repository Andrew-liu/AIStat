import Foundation

final class MemoryStatsModule: @unchecked Sendable {
    private let runner: SystemCommandRunner
    private let pageSizeBytes = 16_384.0

    init(runner: SystemCommandRunner) {
        self.runner = runner
    }

    nonisolated func readDetail() -> MemoryStatsDetail {
        let pages = parseVMStat(runner.run("/usr/bin/vm_stat", arguments: []))
        let totalBytes = Double(readUInt(runner.run("/usr/sbin/sysctl", arguments: ["-n", "hw.memsize"])) ?? 0)
        let wired = bytesFromPages(pages["Pages wired down"])
        let active = bytesFromPages(pages["Pages active"])
        let compressed = bytesFromPages(pages["Pages occupied by compressor"] ?? pages["Pages stored in compressor"])
        let free = bytesFromPages((pages["Pages free"] ?? 0) + (pages["Pages speculative"] ?? 0))
        let inactive = bytesFromPages(pages["Pages inactive"])
        let cached = bytesFromPages(pages["File-backed pages"])
        let used = wired + active + compressed
        let pressure = totalBytes > 0 ? SystemStatsFormatter.clamp(used / totalBytes * 100) : nil
        let swapIns = pages["Swapins"] ?? 0
        let swapOuts = pages["Swapouts"] ?? 0
        let topProcesses = runner.readProcesses(arguments: ["-amcwwwxo", "comm=,rss=,pcpu="], valueIndex: 2, limit: 5).map { process in
            SystemProcessSummary(
                id: "mem-\(process.name)-\(process.index)",
                name: process.name,
                valueText: SystemStatsFormatter.formatBytes(Double(process.rssKB) * 1024),
                detailText: String(format: "%.1f%% CPU", process.cpu)
            )
        }

        return MemoryStatsDetail(
            wiredGB: SystemStatsFormatter.gb(wired),
            activeGB: SystemStatsFormatter.gb(active),
            compressedGB: SystemStatsFormatter.gb(compressed),
            freeGB: SystemStatsFormatter.gb(free + inactive),
            memoryPressurePercent: pressure,
            physicalMemoryText: totalBytes > 0 ? SystemStatsFormatter.formatBytes(totalBytes) : "--",
            usedMemoryText: SystemStatsFormatter.formatBytes(used),
            cachedFilesText: cached > 0 ? SystemStatsFormatter.formatBytes(cached) : "--",
            pageInsText: SystemStatsFormatter.formatInteger(pages["Pageins"]),
            pageOutsText: SystemStatsFormatter.formatInteger(pages["Pageouts"]),
            swapUsageText: (swapIns + swapOuts) == 0 ? "0 B" : "\(SystemStatsFormatter.formatInteger(swapIns)) / \(SystemStatsFormatter.formatInteger(swapOuts))",
            topProcesses: topProcesses
        )
    }

    nonisolated func readPercent(from detail: MemoryStatsDetail) -> Double? {
        detail.memoryPressurePercent
    }

    private nonisolated func parseVMStat(_ output: String?) -> [String: Double] {
        var pages: [String: Double] = [:]
        guard let output else { return pages }
        for line in output.components(separatedBy: .newlines) {
            let parts = line.components(separatedBy: ":")
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"")))
            let digits = parts[1].filter { $0.isNumber }
            guard let value = Double(digits) else { continue }
            pages[key] = value
        }
        return pages
    }

    private nonisolated func bytesFromPages(_ pages: Double?) -> Double {
        (pages ?? 0) * pageSizeBytes
    }

    private nonisolated func readUInt(_ text: String?) -> UInt64? {
        guard let text else { return nil }
        return UInt64(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
