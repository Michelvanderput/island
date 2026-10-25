import Foundation
import CoreGraphics
import ServiceManagement

/// Instellingen, opgeslagen in UserDefaults. Views lezen ze via @AppStorage met dezelfde sleutels.
enum Pref {
    // Algemeen
    static let showMenuBarIcon = "showMenuBarIcon"
    static let displayMode = "displayMode"            // DisplayMode
    static let openMode = "openMode"                  // OpenMode
    static let hoverDelay = "hoverDelay"
    static let hapticFeedback = "hapticFeedback"
    static let hotKeyEnabled = "hotKeyEnabled"

    // Notch
    static let expandedSize = "expandedSize"          // ExpandedSize
    static let defaultTab = "defaultTab"              // DefaultTab
    static let trackChangeHUD = "trackChangeHUD"
    static let lyricsInNotch = "lyricsInNotch"
    static let artworkAccent = "artworkAccent"

    // Media
    static let compactMusic = "compactMusic"
    static let preferredPlayer = "preferredPlayer"    // PreferredPlayer
    static let lyricsEnabled = "lyricsEnabled"
    static let showFavorite = "showFavorite"

    // Vergrendelscherm
    static let lockScreenEnabled = "lockScreenEnabled"
    static let lockScreenLyrics = "lockScreenLyrics"
    static let lockScreenWidgets = "lockScreenWidgets"
    static let lockScreenArtworkScale = "lockScreenArtworkScale"

    // Widgets & meldingen
    static let weatherEnabled = "weatherEnabled"
    static let weatherCity = "weatherCity"
    static let useFahrenheit = "useFahrenheit"
    static let batteryAlerts = "batteryAlerts"
    static let lowBatteryThreshold = "lowBatteryThreshold"
    static let bluetoothAlerts = "bluetoothAlerts"

    // Lade
    static let trayCopyFiles = "trayCopyFiles"
    static let trayClearOnQuit = "trayClearOnQuit"

    static let defaults: [String: Any] = [
        showMenuBarIcon: true,
        displayMode: DisplayMode.builtIn.rawValue,
        openMode: OpenMode.hover.rawValue,
        hoverDelay: 0.15,
        hapticFeedback: true,
        hotKeyEnabled: true,

        expandedSize: ExpandedSize.standard.rawValue,
        defaultTab: DefaultTab.home.rawValue,
        trackChangeHUD: true,
        lyricsInNotch: false,
        artworkAccent: true,

        compactMusic: true,
        preferredPlayer: PreferredPlayer.automatic.rawValue,
        lyricsEnabled: true,
        showFavorite: true,

        lockScreenEnabled: true,
        lockScreenLyrics: true,
        lockScreenWidgets: true,
        lockScreenArtworkScale: 1.0,

        weatherEnabled: true,
        weatherCity: "",
        useFahrenheit: false,
        batteryAlerts: true,
        lowBatteryThreshold: 20,
        bluetoothAlerts: true,

        trayCopyFiles: false,
        trayClearOnQuit: false,
    ]

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: defaults)
    }

    /// Zet alle instellingen terug (de inhoud van de lade blijft staan).
    static func resetAll() {
        for key in defaults.keys { UserDefaults.standard.removeObject(forKey: key) }
    }

    static func bool(_ key: String) -> Bool { UserDefaults.standard.bool(forKey: key) }
    static func string(_ key: String) -> String { UserDefaults.standard.string(forKey: key) ?? "" }
}

enum DisplayMode: String, CaseIterable, Identifiable {
    case builtIn, main, all
    var id: String { rawValue }
    var label: String {
        switch self {
        case .builtIn: return "Ingebouwd scherm (notch)"
        case .main: return "Scherm met menubalk"
        case .all: return "Alle schermen"
        }
    }
    static var current: DisplayMode { DisplayMode(rawValue: Pref.string(Pref.displayMode)) ?? .builtIn }
}

enum OpenMode: String, CaseIterable, Identifiable {
    case hover, click
    var id: String { rawValue }
    var label: String { self == .hover ? "Aanwijzen" : "Klikken" }
    static var current: OpenMode { OpenMode(rawValue: Pref.string(Pref.openMode)) ?? .hover }
}

enum ExpandedSize: String, CaseIterable, Identifiable {
    case compact, standard, large
    var id: String { rawValue }
    var label: String {
        switch self {
        case .compact: return "Compact"
        case .standard: return "Standaard"
        case .large: return "Groot"
        }
    }
    var size: CGSize {
        switch self {
        case .compact: return CGSize(width: 500, height: 132)
        case .standard: return CGSize(width: 560, height: 148)
        case .large: return CGSize(width: 640, height: 184)
        }
    }
    static var current: ExpandedSize { ExpandedSize(rawValue: Pref.string(Pref.expandedSize)) ?? .standard }
}

enum DefaultTab: String, CaseIterable, Identifiable {
    case home, lyrics, last
    var id: String { rawValue }
    var label: String {
        switch self {
        case .home: return "Start"
        case .lyrics: return "Songtekst (als die er is)"
        case .last: return "Laatst geopend"
        }
    }
    static var current: DefaultTab { DefaultTab(rawValue: Pref.string(Pref.defaultTab)) ?? .home }
}

enum PreferredPlayer: String, CaseIterable, Identifiable {
    case automatic, spotify, music
    var id: String { rawValue }
    var label: String {
        switch self {
        case .automatic: return "Automatisch"
        case .spotify: return "Alleen Spotify"
        case .music: return "Alleen Apple Music"
        }
    }
    static var current: PreferredPlayer { PreferredPlayer(rawValue: Pref.string(Pref.preferredPlayer)) ?? .automatic }

    func allows(_ source: MediaSource) -> Bool {
        switch self {
        case .automatic: return true
        case .spotify: return source == .spotify
        case .music: return source == .music
        }
    }
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
