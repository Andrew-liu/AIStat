import Foundation

final class SystemStatsReader: @unchecked Sendable {
    private let runner = SystemCommandRunner()
    private let cpuModule: CPUStatsModule
    private let memoryModule: MemoryStatsModule
    private let diskModule: DiskStatsModule
    private let batteryModule: BatteryStatsModule
    private let networkModule: NetworkStatsModule

    init() {
        cpuModule = CPUStatsModule(runner: runner)
        memoryModule = MemoryStatsModule(runner: runner)
        diskModule = DiskStatsModule(runner: runner)
        batteryModule = BatteryStatsModule(runner: runner)
        networkModule = NetworkStatsModule(runner: runner)
    }

    nonisolated func readSummary(previousNetworkSample: NetworkSample?, previousDiskSample: DiskIOSample?) async -> SystemStatsReadResult {
        await Task.detached(priority: .utility) {
            let networkSample = self.networkModule.readSample()
            let networkSpeeds = self.networkModule.speedTexts(current: networkSample, previous: previousNetworkSample)
            let diskSample = self.diskModule.readIOSample()
            let diskSpeeds = self.diskModule.speedTexts(current: diskSample, previous: previousDiskSample)
            let cpuDetail = self.cpuModule.readDetail()
            let memoryDetail = self.memoryModule.readDetail()
            let diskDetail = self.diskModule.readDetail()
            let batteryPercent = self.batteryModule.readPercent()
            let batteryDetail = self.batteryModule.readDetail(percent: batteryPercent)

            let summary = SystemStatsSummary(
                cpuPercent: self.cpuModule.readPercent(from: cpuDetail),
                memoryPercent: self.memoryModule.readPercent(from: memoryDetail),
                diskPercent: self.diskModule.readPercent(from: diskDetail),
                batteryPercent: batteryPercent,
                uploadSpeedText: networkSpeeds.upload,
                downloadSpeedText: networkSpeeds.download,
                diskReadSpeedText: diskSpeeds.read,
                diskWriteSpeedText: diskSpeeds.write,
                cpuDetail: cpuDetail,
                memoryDetail: memoryDetail,
                diskDetail: diskDetail,
                batteryDetail: batteryDetail,
                updatedAt: Date()
            )
            return SystemStatsReadResult(summary: summary, networkSample: networkSample, diskSample: diskSample)
        }.value
    }
}
