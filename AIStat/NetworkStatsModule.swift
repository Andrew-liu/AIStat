import Foundation

final class NetworkStatsModule: @unchecked Sendable {
    private let runner: SystemCommandRunner

    init(runner: SystemCommandRunner) {
        self.runner = runner
    }

    nonisolated func readSample() -> NetworkSample? {
        guard let output = runner.run("/usr/sbin/netstat", arguments: ["-ibn"]) else { return nil }
        var inputBytes: UInt64 = 0
        var outputBytes: UInt64 = 0

        for line in output.split(whereSeparator: \.isNewline) {
            let columns = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard columns.count >= 10 else { continue }
            let name = String(columns[0])
            let network = String(columns[2])
            guard !name.hasPrefix("lo"), !name.hasPrefix("utun"), network.hasPrefix("<Link#") else { continue }
            inputBytes += UInt64(columns[6]) ?? 0
            outputBytes += UInt64(columns[9]) ?? 0
        }

        return NetworkSample(timestamp: Date(), inputBytes: inputBytes, outputBytes: outputBytes)
    }

    nonisolated func speedTexts(current: NetworkSample?, previous: NetworkSample?) -> (upload: String, download: String) {
        guard let current, let previous else {
            return ("↑0 B/s", "↓0 B/s")
        }
        let interval = max(0.25, current.timestamp.timeIntervalSince(previous.timestamp))
        let inputDelta = current.inputBytes >= previous.inputBytes ? current.inputBytes - previous.inputBytes : 0
        let outputDelta = current.outputBytes >= previous.outputBytes ? current.outputBytes - previous.outputBytes : 0
        return (
            "↑\(SystemStatsFormatter.formatByteRate(Double(outputDelta) / interval))",
            "↓\(SystemStatsFormatter.formatByteRate(Double(inputDelta) / interval))"
        )
    }
}
