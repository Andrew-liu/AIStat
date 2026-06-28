import Foundation
import IOKit.ps

final class BatteryStatsModule: @unchecked Sendable {
    private let runner: SystemCommandRunner

    init(runner: SystemCommandRunner) {
        self.runner = runner
    }

    nonisolated func readPercent() -> Double? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  let current = description[kIOPSCurrentCapacityKey] as? NSNumber,
                  let maximum = description[kIOPSMaxCapacityKey] as? NSNumber,
                  maximum.doubleValue > 0 else { continue }
            return SystemStatsFormatter.clamp(current.doubleValue / maximum.doubleValue * 100)
        }
        return nil
    }

    nonisolated func readDetail(percent: Double?) -> BatteryStatsDetail {
        let power = runner.run("/usr/sbin/system_profiler", arguments: ["SPPowerDataType"]) ?? ""
        let ioreg = runner.run("/usr/sbin/ioreg", arguments: ["-rn", "AppleSmartBattery"]) ?? ""
        let charging = boolField("IsCharging", in: ioreg) ?? power.localizedCaseInsensitiveContains("Charging: Yes")
        let external = boolField("ExternalConnected", in: ioreg) ?? power.localizedCaseInsensitiveContains("Connected: Yes")
        let stateText: String
        if charging {
            stateText = "Charging"
        } else if external {
            stateText = "Connected"
        } else {
            stateText = "Discharging"
        }

        let health = number(after: "Maximum Capacity:", in: power)
        let cycle = intField("CycleCount", in: ioreg) ?? integer(after: "Cycle Count:", in: power)
        let designCycle = intField("DesignCycleCount9C", in: ioreg) ?? 1000
        let watts = intFromAdapterDetails(in: ioreg) ?? integer(after: "Wattage (W):", in: power)
        let tempRaw = intField("Temperature", in: ioreg)
        let temperature = tempRaw.map { String(format: "%.0f°", Double($0) / 100.0) } ?? "--"
        let current = intField("AppleRawCurrentCapacity", in: ioreg)
        let full = intField("AppleRawMaxCapacity", in: ioreg)
        let design = intField("DesignCapacity", in: ioreg)
        let timeRemaining = intField("TimeRemaining", in: ioreg)

        return BatteryStatsDetail(
            stateText: percent.map { "\(stateText) · \(Int($0.rounded()))%" } ?? stateText,
            timeRemainingText: formatBatteryTime(minutes: timeRemaining, charging: charging),
            healthPercent: health,
            conditionText: text(after: "Condition:", in: power) ?? "--",
            cycleCountText: cycle.map { "\($0) of \(designCycle)" } ?? "--",
            powerAdapterText: watts.map { "\($0) W" } ?? (external ? "Connected" : "Not connected"),
            temperatureText: temperature,
            timeOnACText: external ? "Connected" : "--",
            remainingCapacityText: current.map { "\($0) mAh" } ?? "--",
            fullChargeCapacityText: full.map { "\($0) mAh" } ?? "--",
            designChargeCapacityText: design.map { "\($0) mAh" } ?? "--"
        )
    }

    private nonisolated func number(after marker: String, in text: String) -> Double? {
        guard let range = text.range(of: marker) else { return nil }
        let tail = text[range.upperBound...]
        return tail.regexMatches(for: #"[0-9]+(?:\.[0-9]+)?"#).first.flatMap(Double.init)
    }

    private nonisolated func integer(after marker: String, in text: String) -> Int? {
        guard let range = text.range(of: marker) else { return nil }
        let tail = text[range.upperBound...]
        return tail.regexMatches(for: #"[0-9]+"#).first.flatMap(Int.init)
    }

    private nonisolated func text(after marker: String, in text: String) -> String? {
        guard let range = text.range(of: marker) else { return nil }
        return text[range.upperBound...]
            .split(whereSeparator: \.isNewline)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated func intField(_ key: String, in text: String) -> Int? {
        text.regexMatches(for: "\\\"\(key)\\\"\\s*=\\s*(-?[0-9]+)").first.flatMap(Int.init)
    }

    private nonisolated func boolField(_ key: String, in text: String) -> Bool? {
        if text.range(of: "\\\"\(key)\\\"\\s*=\\s*Yes", options: .regularExpression) != nil { return true }
        if text.range(of: "\\\"\(key)\\\"\\s*=\\s*No", options: .regularExpression) != nil { return false }
        return nil
    }

    private nonisolated func intFromAdapterDetails(in text: String) -> Int? {
        text.regexMatches(for: #"\"Watts\"\s*=\s*([0-9]+)"#).first.flatMap(Int.init)
    }

    private nonisolated func formatBatteryTime(minutes: Int?, charging: Bool) -> String {
        guard let minutes, minutes > 0, minutes < 65_535 else { return charging ? "Calculating charge time" : "Calculating remaining" }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return charging ? "\(hours):\(String(format: "%02d", mins)) until charged" : "\(hours):\(String(format: "%02d", mins)) remaining"
        }
        return charging ? "\(mins)m until charged" : "\(mins)m remaining"
    }
}
