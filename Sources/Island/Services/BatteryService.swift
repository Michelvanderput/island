import Foundation
import IOKit.ps

/// Batterijstatus via IOKit power source notificaties (event driven, op de main run loop).
final class BatteryService: ObservableObject {
    @Published private(set) var level: Int = 100
    @Published private(set) var isCharging = false
    @Published private(set) var isPluggedIn = false
    @Published private(set) var hasBattery = false
    @Published private(set) var isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

    /// Wordt aangeroepen bij inpluggen/uittrekken en bij lage batterij.
    var onEvent: ((HUD) -> Void)?

    private var runLoopSource: CFRunLoopSource?
    private var lowWarned: Set<Int> = []
    private var started = false

    func start() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            Unmanaged<BatteryService>.fromOpaque(ctx).takeUnretainedValue().update()
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = source
        }
        NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        update()
        started = true
    }

    /// De ingestelde drempel plus 10 % en 5 %.
    private var thresholds: [Int] {
        let configured = UserDefaults.standard.integer(forKey: Pref.lowBatteryThreshold)
        return Array(Set([5, 10, configured > 0 ? configured : 20])).sorted()
    }

    private func update() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return }

        for ps in list {
            guard let desc = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any],
                  (desc["Type"] as? String) == "InternalBattery" else { continue }

            let current = desc["Current Capacity"] as? Int ?? 0
            let max = desc["Max Capacity"] as? Int ?? 100
            let newLevel = max > 0 ? Int((Double(current) / Double(max) * 100).rounded()) : current
            let plugged = (desc["Power Source State"] as? String) == "AC Power"
            let charging = desc["Is Charging"] as? Bool ?? false

            let pluggedChanged = hasBattery && plugged != isPluggedIn
            hasBattery = true
            level = newLevel
            isCharging = charging
            isPluggedIn = plugged

            guard started, Pref.bool(Pref.batteryAlerts) else { return }
            if pluggedChanged {
                onEvent?(.charging(level: newLevel, pluggedIn: plugged))
            }
            if plugged {
                lowWarned.removeAll()
            } else if let threshold = thresholds.first(where: { newLevel <= $0 && !lowWarned.contains($0) }) {
                // Alle drempels boven het huidige niveau gelden als gemeld.
                lowWarned.formUnion(thresholds.filter { $0 >= threshold })
                onEvent?(.lowBattery(level: newLevel))
            }
            return
        }
    }
}
