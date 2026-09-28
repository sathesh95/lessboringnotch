import Cocoa
import Combine
import Defaults
import Foundation
import IOKit.ps
import SwiftUI

/// A view model that manages and monitors the battery status of the device
class BatteryStatusViewModel: ObservableObject {

    private var wasCharging: Bool = false
    private var powerSourceChangedCallback: IOPowerSourceCallbackType?
    private var runLoopSource: Unmanaged<CFRunLoopSource>?

    @ObservedObject var coordinator = BoringViewCoordinator.shared

    @Published private(set) var levelBattery: Float = 0.0
    @Published private(set) var maxCapacity: Float = 0.0
    @Published private(set) var isPluggedIn: Bool = false
    @Published private(set) var isCharging: Bool = false
    @Published private(set) var isInLowPowerMode: Bool = false
    @Published private(set) var isInitial: Bool = false
    @Published private(set) var timeToFullCharge: Int = 0
    @Published private(set) var statusText: String = ""

    // MARK: - Critical Battery Alert (<10%)
    @Published private(set) var isCriticalBattery: Bool = false
    @Published private(set) var currentCriticalMessage: String = "Charge your laptop you moron! 😡"
    private var messageRotationTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    static let criticalBatteryMessages: [String] = [
        "Charge your laptop you moron! 😡",
        "Don't Let me Die 😔",
        "Feed me electricity! ⚡️😭",
        "I'm literally dying right now... 🪫💀",
        "Plug me in, I'm begging you! 🥺🔌",
        "Find a charger NOW! 🚨😱",
        "Darkness is approaching... 🪫🌑",
        "Save your work or weep! ⚠️💾",
        "10% and fading fast! 🔌🏃💨",
        "I have so much left to live for! 😭⚡️"
    ]

    var displayedBatteryLevel: Int {
        if Defaults[.testCriticalBatteryAlert] && (levelBattery > 10 || isPluggedIn) {
            return 7
        }
        return Int(levelBattery)
    }

    private let managerBattery = BatteryActivityManager.shared
    private var managerBatteryId: Int?

    static let shared = BatteryStatusViewModel()

    /// Initializes the view model with a given BoringViewModel instance
    /// - Parameter vm: The BoringViewModel instance
    private init() {
        setupPowerStatus()
        setupMonitor()
        setupPreferenceObservers()
        checkCriticalBatteryStatus()
    }

    private func setupPreferenceObservers() {
        Defaults.publisher(.testCriticalBatteryAlert)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.checkCriticalBatteryStatus()
            }
            .store(in: &cancellables)

        Defaults.publisher(.criticalBatteryWarning)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.checkCriticalBatteryStatus()
            }
            .store(in: &cancellables)
    }

    func rotateCriticalMessage() {
        let pool = Self.criticalBatteryMessages.filter { $0 != currentCriticalMessage }
        if let next = pool.randomElement() {
            withAnimation(.smooth) {
                currentCriticalMessage = next
            }
        }
    }

    func checkCriticalBatteryStatus() {
        let isSimulated = Defaults[.testCriticalBatteryAlert]
        let isRealLow = levelBattery > 0 && levelBattery <= 10 && !isPluggedIn && !isCharging && Defaults[.criticalBatteryWarning]
        let shouldAlert = isSimulated || isRealLow

        if shouldAlert != isCriticalBattery {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                self.isCriticalBattery = shouldAlert
            }
            if shouldAlert {
                rotateCriticalMessage()
                startRotatingCriticalMessages()
            } else {
                stopRotatingCriticalMessages()
            }
        }
    }

    private func startRotatingCriticalMessages() {
        stopRotatingCriticalMessages()
        messageRotationTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.rotateCriticalMessage()
            }
        }
    }

    private func stopRotatingCriticalMessages() {
        messageRotationTimer?.invalidate()
        messageRotationTimer = nil
    }

    /// Sets up the initial power status by fetching battery information
    private func setupPowerStatus() {
        let batteryInfo = managerBattery.initializeBatteryInfo()
        updateBatteryInfo(batteryInfo)
    }

    /// Sets up the monitor to observe battery events
    private func setupMonitor() {
        managerBatteryId = managerBattery.addObserver { [weak self] event in
            guard let self = self else { return }
            self.handleBatteryEvent(event)
        }
    }

    /// Handles battery events and updates the corresponding properties
    /// - Parameter event: The battery event to handle
    private func handleBatteryEvent(_ event: BatteryActivityManager.BatteryEvent) {
        switch event {
        case .powerSourceChanged(let isPluggedIn):
            print("🔌 Power source: \(isPluggedIn ? "Connected" : "Disconnected")")
            withAnimation {
                self.isPluggedIn = isPluggedIn
                self.statusText = isPluggedIn ? "Plugged In" : "Unplugged"
                self.notifyImportanChangeStatus()
                self.checkCriticalBatteryStatus()
            }

        case .batteryLevelChanged(let level):
            print("🔋 Battery level: \(Int(level))%")
            withAnimation {
                self.levelBattery = level
                self.checkCriticalBatteryStatus()
            }

        case .lowPowerModeChanged(let isEnabled):
            print("⚡ Low power mode: \(isEnabled ? "Enabled" : "Disabled")")
            self.notifyImportanChangeStatus()
            withAnimation {
                self.isInLowPowerMode = isEnabled
                self.statusText = "Low Power: \(self.isInLowPowerMode ? "On" : "Off")"
            }

        case .isChargingChanged(let isCharging):
            print("🔌 Charging: \(isCharging ? "Yes" : "No")")
            print("maxCapacity: \(self.maxCapacity)")
            print("levelBattery: \(self.levelBattery)")
            self.notifyImportanChangeStatus()
            withAnimation {
                self.isCharging = isCharging
                self.statusText =
                    isCharging
                    ? "Charging battery"
                    : (self.levelBattery < self.maxCapacity ? "Not charging" : "Full charge")
                self.checkCriticalBatteryStatus()
            }

        case .timeToFullChargeChanged(let time):
            print("🕒 Time to full charge: \(time) minutes")
            withAnimation {
                self.timeToFullCharge = time
            }

        case .maxCapacityChanged(let capacity):
            print("🔋 Max capacity: \(capacity)")
            withAnimation {
                self.maxCapacity = capacity
            }

        case .error(let description):
            print("⚠️ Error: \(description)")
        }
    }

    /// Updates the battery information with the given BatteryInfo instance
    /// - Parameter batteryInfo: The BatteryInfo instance containing the battery data
    private func updateBatteryInfo(_ batteryInfo: BatteryInfo) {
        withAnimation {
            self.levelBattery = batteryInfo.currentCapacity
            self.isPluggedIn = batteryInfo.isPluggedIn
            self.isCharging = batteryInfo.isCharging
            self.isInLowPowerMode = batteryInfo.isInLowPowerMode
            self.timeToFullCharge = batteryInfo.timeToFullCharge
            self.maxCapacity = batteryInfo.maxCapacity
            self.statusText = batteryInfo.isPluggedIn ? "Plugged In" : "Unplugged"
            self.checkCriticalBatteryStatus()
        }
    }

    /// Notifies important changes in the battery status with an optional delay
    /// - Parameter delay: The delay before notifying the change, default is 0.0
    private func notifyImportanChangeStatus(delay: Double = 0.0) {
        Task {
            try? await Task.sleep(for: .seconds(delay))
            self.coordinator.toggleExpandingView(status: true, type: .battery)
        }
    }

    deinit {
        print("🔌 Cleaning up battery monitoring...")
        stopRotatingCriticalMessages()
        cancellables.removeAll()
        if let managerBatteryId: Int = managerBatteryId {
            managerBattery.removeObserver(byId: managerBatteryId)
        }
    }

}
