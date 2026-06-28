import Foundation

final class DiskStatsModule: @unchecked Sendable {
    private let runner: SystemCommandRunner

    init(runner: SystemCommandRunner) {
        self.runner = runner
    }

    nonisolated func readDetail() -> DiskStatsDetail {
        guard let output = runner.run("/bin/zsh", arguments: ["-c", "setopt NULL_GLOB; df -kP / /System/Volumes/Data /Volumes/* 2>/dev/null"]) else {
            return .empty
        }

        var seenMounts = Set<String>()
        var volumes: [DiskVolumeDetail] = []
        for line in output.split(whereSeparator: \.isNewline).dropFirst() {
            let columns = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard columns.count >= 6,
                  let usedKB = Double(columns[2]),
                  let availableKB = Double(columns[3]) else { continue }
            let mountPoint = columns[5...].joined(separator: " ")
            guard !seenMounts.contains(mountPoint) else { continue }
            seenMounts.insert(mountPoint)
            let totalKB = usedKB + availableKB
            let usedPercent = totalKB > 0 ? SystemStatsFormatter.clamp(usedKB / totalKB * 100) : 0
            volumes.append(
                DiskVolumeDetail(
                    id: mountPoint,
                    name: displayVolumeName(for: mountPoint),
                    mountPoint: mountPoint,
                    usedText: SystemStatsFormatter.formatBytes(usedKB * 1024),
                    freeText: SystemStatsFormatter.formatBytes(availableKB * 1024),
                    usedPercent: usedPercent
                )
            )
        }
        return DiskStatsDetail(volumes: volumes)
    }

    nonisolated func readPercent(from detail: DiskStatsDetail) -> Double? {
        detail.volumes.first(where: { $0.mountPoint == "/System/Volumes/Data" })?.usedPercent ?? detail.volumes.first?.usedPercent
    }

    nonisolated func readIOSample() -> DiskIOSample? {
        guard let output = runner.run("/usr/bin/top", arguments: ["-l", "1", "-n", "0"]),
              let line = output.components(separatedBy: .newlines).first(where: { $0.hasPrefix("Disks:") }) else {
            return nil
        }
        let values = line.regexMatches(for: #"/[[:space:]]*([0-9]+(?:\.[0-9]+)?[KMGT]?)"#)
        guard values.count >= 2,
              let readBytes = parseByteCount(values[0]),
              let writtenBytes = parseByteCount(values[1]) else {
            return nil
        }
        return DiskIOSample(timestamp: Date(), readBytes: readBytes, writtenBytes: writtenBytes)
    }

    nonisolated func speedTexts(current: DiskIOSample?, previous: DiskIOSample?) -> (read: String, write: String) {
        guard let current, let previous else {
            return ("R 0 B/s", "W 0 B/s")
        }
        let interval = max(0.25, current.timestamp.timeIntervalSince(previous.timestamp))
        let readDelta = current.readBytes >= previous.readBytes ? current.readBytes - previous.readBytes : 0
        let writeDelta = current.writtenBytes >= previous.writtenBytes ? current.writtenBytes - previous.writtenBytes : 0
        return (
            "R \(SystemStatsFormatter.formatByteRate(Double(readDelta) / interval))",
            "W \(SystemStatsFormatter.formatByteRate(Double(writeDelta) / interval))"
        )
    }

    private nonisolated func displayVolumeName(for mountPoint: String) -> String {
        if mountPoint == "/" || mountPoint == NSHomeDirectory() || mountPoint == "/System/Volumes/Data" {
            return "Macintosh HD"
        }
        return URL(fileURLWithPath: mountPoint).lastPathComponent
    }

    private nonisolated func parseByteCount(_ text: String) -> UInt64? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let numberPart = trimmed.dropLast(trimmed.last?.isLetter == true ? 1 : 0)
        guard let value = Double(numberPart) else { return nil }
        let multiplier: Double
        switch trimmed.last {
        case "K": multiplier = 1_024
        case "M": multiplier = 1_048_576
        case "G": multiplier = 1_073_741_824
        case "T": multiplier = 1_099_511_627_776
        default: multiplier = 1
        }
        return UInt64(value * multiplier)
    }
}
