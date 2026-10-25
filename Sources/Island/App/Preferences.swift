import Foundation
import ServiceManagement

/// Instellingen, opgeslagen in UserDefaults. Views lezen ze via @AppStorage met dezelfde sleutels.
enum Pref {
    static let showMenuBarIcon = "showMenuBarIcon"
    static let showOnAllDisplays = "showOnAllDisplays"
    static let lyricsEnabled = "lyricsEnabled"
    static let weatherEnabled = "weatherEnabled"
    static let weatherCity = "weatherCity"
    static let useFahrenheit = "useFahrenheit"
    static let batteryAlerts = "batteryAlerts"
    static let bluetoothAlerts = "bluetoothAlerts"
    static let compactMusic = "compactMusic"
    static let hoverDelay = "hoverDelay"
    static let hapticFeedback = "hapticFeedback"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            showMenuBarIcon: true,
            showOnAllDisplays: false,
            lyricsEnabled: true,
            weatherEnabled: true,
            weatherCity: "",
            useFahrenheit: false,
            batteryAlerts: true,
            bluetoothAlerts: true,
            compactMusic: true,
            hoverDelay: 0.15,
            hapticFeedback: true,
        ])
    }

    static func bool(_ key: String) -> Bool { UserDefaults.standard.bool(forKey: key) }
}

enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Island: launch at login mislukt: \(error)")
        }
    }
}
