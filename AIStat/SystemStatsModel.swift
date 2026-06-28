import Foundation
import Combine

struct SystemProcessSummary: Identifiable, Sendable {
    let id: String
    let name: String
    let valueText: String
    let detailText: String
}

struct CPUStatsDetail: Sendable {
    var userPercent: Double?
    var systemPercent: Double?
    var idlePercent: Double?
    var load1: Double?
    var load5: Double?
    var load15: Double?
    var stateText: String
    var gpuPercent: Double?
    var gpuMemoryUsedText: String
    var gpuMemoryTotalText: String
    var socName: String
    var systemHealthText: String
    var uptimeText: String
    var topProcesses: [SystemProcessSummary]

    nonisolated static let empty = CPUStatsDetail(
        userPercent: nil,
        systemPercent: nil,
        idlePercent: nil,
        load1: nil,
        load5: nil,
        load15: nil,
        stateText: "Balanced",
        gpuPercent: nil,
        gpuMemoryUsedText: "--",
        gpuMemoryTotalText: "--",
        socName: "--",
        systemHealthText: "Nominal",
        uptimeText: "--",
        topProcesses: []
    )
}

struct MemoryStatsDetail: Sendable {
    var wiredGB: Double?
    var activeGB: Double?
    var compressedGB: Double?
    var freeGB: Double?
    var memoryPressurePercent: Double?
    var physicalMemoryText: String
    var usedMemoryText: String
    var cachedFilesText: String
    var pageInsText: String
    var pageOutsText: String
    var swapUsageText: String
    var topProcesses: [SystemProcessSummary]

    nonisolated static let empty = MemoryStatsDetail(
        wiredGB: nil,
        activeGB: nil,
        compressedGB: nil,
        freeGB: nil,
        memoryPressurePercent: nil,
        physicalMemoryText: "--",
        usedMemoryText: "--",
        cachedFilesText: "--",
        pageInsText: "--",
        pageOutsText: "--",
        swapUsageText: "--",
        topProcesses: []
    )
}

struct DiskVolumeDetail: Identifiable, Sendable {
    let id: String
    let name: String
    let mountPoint: String
    let usedText: String
    let freeText: String
    let usedPercent: Double
}

struct DiskStatsDetail: Sendable {
    var volumes: [DiskVolumeDetail]

    nonisolated static let empty = DiskStatsDetail(volumes: [])
}

struct BatteryStatsDetail: Sendable {
    var stateText: String
    var timeRemainingText: String
    var healthPercent: Double?
    var conditionText: String
    var cycleCountText: String
    var powerAdapterText: String
    var temperatureText: String
    var timeOnACText: String
    var remainingCapacityText: String
    var fullChargeCapacityText: String
    var designChargeCapacityText: String

    nonisolated static let empty = BatteryStatsDetail(
        stateText: "Unknown",
        timeRemainingText: "--",
        healthPercent: nil,
        conditionText: "--",
        cycleCountText: "--",
        powerAdapterText: "--",
        temperatureText: "--",
        timeOnACText: "--",
        remainingCapacityText: "--",
        fullChargeCapacityText: "--",
        designChargeCapacityText: "--"
    )
}

struct SystemStatsSummary: Sendable {
    var cpuPercent: Double?
    var memoryPercent: Double?
    var diskPercent: Double?
    var batteryPercent: Double?
    var uploadSpeedText: String
    var downloadSpeedText: String
    var diskReadSpeedText: String
    var diskWriteSpeedText: String
    var cpuDetail: CPUStatsDetail
    var memoryDetail: MemoryStatsDetail
    var diskDetail: DiskStatsDetail
    var batteryDetail: BatteryStatsDetail
    var updatedAt: Date?

    static let empty = SystemStatsSummary()

    nonisolated init(
        cpuPercent: Double? = nil,
        memoryPercent: Double? = nil,
        diskPercent: Double? = nil,
        batteryPercent: Double? = nil,
        uploadSpeedText: String = "↑--",
        downloadSpeedText: String = "↓--",
        diskReadSpeedText: String = "R --",
        diskWriteSpeedText: String = "W --",
        cpuDetail: CPUStatsDetail = .empty,
        memoryDetail: MemoryStatsDetail = .empty,
        diskDetail: DiskStatsDetail = .empty,
        batteryDetail: BatteryStatsDetail = .empty,
        updatedAt: Date? = nil
    ) {
        self.cpuPercent = cpuPercent
        self.memoryPercent = memoryPercent
        self.diskPercent = diskPercent
        self.batteryPercent = batteryPercent
        self.uploadSpeedText = uploadSpeedText
        self.downloadSpeedText = downloadSpeedText
        self.diskReadSpeedText = diskReadSpeedText
        self.diskWriteSpeedText = diskWriteSpeedText
        self.cpuDetail = cpuDetail
        self.memoryDetail = memoryDetail
        self.diskDetail = diskDetail
        self.batteryDetail = batteryDetail
        self.updatedAt = updatedAt
    }
}

struct NetworkSample: Sendable {
    let timestamp: Date
    let inputBytes: UInt64
    let outputBytes: UInt64
}

struct DiskIOSample: Sendable {
    let timestamp: Date
    let readBytes: UInt64
    let writtenBytes: UInt64
}

struct SystemStatsReadResult: Sendable {
    let summary: SystemStatsSummary
    let networkSample: NetworkSample?
    let diskSample: DiskIOSample?
}

@MainActor
final class SystemStatsModel: ObservableObject {
    @Published private(set) var summary = SystemStatsSummary.empty

    private let reader = SystemStatsReader()
    private var refreshTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?
    private var lastNetworkSample: NetworkSample?
    private var lastDiskSample: DiskIOSample?

    init() {
        refresh()
        startPolling()
    }

    deinit {
        refreshTask?.cancel()
        pollingTask?.cancel()
    }

    func refresh() {
        let previousNetworkSample = lastNetworkSample
        let previousDiskSample = lastDiskSample
        refreshTask?.cancel()
        refreshTask = Task { [reader] in
            let result = await reader.readSummary(previousNetworkSample: previousNetworkSample, previousDiskSample: previousDiskSample)
            guard !Task.isCancelled else { return }
            summary = result.summary
            lastNetworkSample = result.networkSample
            lastDiskSample = result.diskSample
        }
    }

    private func startPolling() {
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                guard let self else { return }
                self.refresh()
            }
        }
    }
}
