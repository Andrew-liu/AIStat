import Foundation

struct ParsedSystemProcess: Sendable {
    let index: Int
    let name: String
    let cpu: Double
    let rssKB: Int
}

final class SystemCommandRunner: @unchecked Sendable {
    nonisolated func run(_ executable: String, arguments: [String]) -> String? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            return String(decoding: data, as: UTF8.self)
        } catch {
            return nil
        }
    }

    nonisolated func readProcesses(arguments: [String], valueIndex: Int, limit: Int) -> [ParsedSystemProcess] {
        guard let output = run("/bin/ps", arguments: arguments) else { return [] }
        var processes: [ParsedSystemProcess] = []
        for (index, line) in output.split(whereSeparator: \.isNewline).enumerated() {
            let columns = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard columns.count >= 3,
                  let firstNumber = Double(columns[columns.count - 2]),
                  let secondNumber = Double(columns[columns.count - 1]) else { continue }
            let name = columns.dropLast(2).joined(separator: " ")
            let cpu: Double
            let rss: Int
            if valueIndex == 1 {
                cpu = firstNumber
                rss = Int(secondNumber)
            } else {
                rss = Int(firstNumber)
                cpu = secondNumber
            }
            processes.append(ParsedSystemProcess(index: index, name: SystemStatsFormatter.shortenProcessName(name), cpu: cpu, rssKB: rss))
        }
        return Array(processes.prefix(limit))
    }
}

enum SystemStatsFormatter {
    nonisolated static func clamp(_ value: Double) -> Double {
        max(0, min(100, value))
    }

    nonisolated static func formatByteRate(_ bytesPerSecond: Double) -> String {
        formatBytes(bytesPerSecond, suffix: "/s", decimals: 1)
    }

    nonisolated static func formatBytes(_ bytes: Double, suffix: String = "", decimals: Int = 2) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = max(0, bytes)
        var unitIndex = 0
        while value >= 1024, unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        if unitIndex == 0 { return "\(Int(value.rounded())) \(units[unitIndex])\(suffix)" }
        return String(format: "%.*f %@%@", decimals, value, units[unitIndex], suffix)
    }

    nonisolated static func formatInteger(_ value: Double?) -> String {
        guard let value else { return "--" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    nonisolated static func gb(_ bytes: Double) -> Double {
        bytes / 1_073_741_824
    }

    nonisolated static func shortenProcessName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = trimmed.split(separator: "/").last.map(String.init) ?? trimmed
        if last.count > 22 { return String(last.prefix(19)) + "…" }
        return last
    }
}

extension StringProtocol {
    nonisolated func regexMatches(for pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let string = String(self)
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        return regex.matches(in: string, range: range).compactMap { match in
            let captureRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range(at: 0)
            guard let swiftRange = Range(captureRange, in: string) else { return nil }
            return String(string[swiftRange])
        }
    }
}
