import Foundation
import IOKit.pwr_mgt
import Combine

enum AwakeMode: String, CaseIterable, Identifiable {
    case off
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case twoHours
    case fourHours
    case forever

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .fifteenMinutes: return "15m"
        case .thirtyMinutes: return "30m"
        case .oneHour: return "1h"
        case .twoHours: return "2h"
        case .fourHours: return "4h"
        case .forever: return "∞"
        }
    }

    var duration: TimeInterval? {
        switch self {
        case .off: return 0
        case .fifteenMinutes: return 900
        case .thirtyMinutes: return 1_800
        case .oneHour: return 3_600
        case .twoHours: return 7_200
        case .fourHours: return 14_400
        case .forever: return nil
        }
    }
}

@MainActor
final class AwakeController: ObservableObject {
    @Published private(set) var mode: AwakeMode = .off
    @Published private(set) var endsAt: Date?
    @Published private(set) var remainingText = "Sleep allowed"
    @Published private(set) var detailText = "Normal power settings"

    private var systemAssertionID = IOPMAssertionID(0)
    private var displayAssertionID = IOPMAssertionID(0)
    private var expirationTask: Task<Void, Never>?
    private var tickerTask: Task<Void, Never>?

    deinit {
        expirationTask?.cancel()
        tickerTask?.cancel()
        if systemAssertionID != 0 {
            IOPMAssertionRelease(systemAssertionID)
        }
        if displayAssertionID != 0 {
            IOPMAssertionRelease(displayAssertionID)
        }
    }

    var isKeepingAwake: Bool {
        mode != .off
    }

    var statusText: String {
        remainingText
    }

    func setMode(_ newMode: AwakeMode) {
        expirationTask?.cancel()
        if newMode == .off {
            releaseAssertions()
            mode = .off
            endsAt = nil
            remainingText = "Sleep allowed"
            detailText = "Normal power settings"
            return
        }

        guard enableAwakeMode() else {
            mode = .off
            endsAt = nil
            remainingText = "Unable to keep awake"
            detailText = "Power assertion failed"
            return
        }

        mode = newMode
        if let duration = newMode.duration {
            endsAt = Date().addingTimeInterval(duration)
            expirationTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.setMode(.off)
            }
        } else {
            endsAt = nil
        }
        detailText = "Prevents system sleep and display dimming"
        updateRemainingText()
        startTickerIfNeeded()
    }

    func toggleDefault() {
        setMode(isKeepingAwake ? .off : .forever)
    }

    private func enableAwakeMode() -> Bool {
        guard systemAssertionID == 0, displayAssertionID == 0 else { return true }

        var newSystemAssertionID = IOPMAssertionID(0)
        let systemResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "AIStat Keep Mac Awake" as CFString,
            &newSystemAssertionID
        )
        guard systemResult == kIOReturnSuccess else { return false }

        var newDisplayAssertionID = IOPMAssertionID(0)
        let displayResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "AIStat Keep Display Awake" as CFString,
            &newDisplayAssertionID
        )
        guard displayResult == kIOReturnSuccess else {
            IOPMAssertionRelease(newSystemAssertionID)
            return false
        }

        systemAssertionID = newSystemAssertionID
        displayAssertionID = newDisplayAssertionID
        return true
    }

    private func releaseAssertions() {
        if systemAssertionID != 0 {
            IOPMAssertionRelease(systemAssertionID)
            systemAssertionID = 0
        }
        if displayAssertionID != 0 {
            IOPMAssertionRelease(displayAssertionID)
            displayAssertionID = 0
        }
    }

    private func startTickerIfNeeded() {
        guard tickerTask == nil else { return }
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                guard let self else { return }
                self.updateRemainingText()
            }
        }
    }

    private func updateRemainingText() {
        guard mode != .off else {
            remainingText = "Sleep allowed"
            return
        }
        guard let endsAt else {
            remainingText = "Keeping awake indefinitely"
            return
        }
        let seconds = max(0, Int(endsAt.timeIntervalSinceNow))
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        if hours > 0 {
            remainingText = "\(hours)h \(minutes)m remaining"
        } else {
            remainingText = "\(max(1, minutes))m remaining"
        }
    }
}
