import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controllers: [NotchWindowController] = []
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var hotKey: HotKey?
    private var cancellables = Set<AnyCancellable>()

    let state = IslandState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Pref.registerDefaults()
        state.openSettings = { [weak self] in self?.showSettings() }
        state.isAnyIslandExpanded = { [weak self] in self?.controllers.contains { $0.isExpanded } ?? false }
        state.start()
        rebuildWindows()

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildWindows() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.applyPreferences() }
            .store(in: &cancellables)

        applyPreferences()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if Pref.bool(Pref.trayClearOnQuit) { state.tray.clear() }
    }

    private var lastDisplayMode: DisplayMode?
    private var lastPlayer: PreferredPlayer?

    private func applyPreferences() {
        updateStatusItem()

        let mode = DisplayMode.current
        if lastDisplayMode != nil, lastDisplayMode != mode { rebuildWindows() }
        lastDisplayMode = mode

        let player = PreferredPlayer.current
        if lastPlayer != nil, lastPlayer != player { state.nowPlaying.reload() }
        lastPlayer = player

        if Pref.bool(Pref.hotKeyEnabled) {
            if hotKey == nil { hotKey = HotKey { [weak self] in self?.toggleIslandFromHotKey() } }
        } else {
            hotKey = nil
        }
    }

    private func rebuildWindows() {
        controllers.forEach { $0.close() }
        controllers.removeAll()

        let screens: [NSScreen]
        switch DisplayMode.current {
        case .all:
            screens = NSScreen.screens
        case .main:
            screens = [NSScreen.screens.first].compactMap { $0 }
        case .builtIn:
            let notched = NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
            screens = [notched ?? NSScreen.screens.first].compactMap { $0 }
        }
        controllers = screens.map { NotchWindowController(screen: $0, state: state) }
    }

    /// De sneltoets opent het eiland op het scherm waar de muis is.
    private func toggleIslandFromHotKey() {
        let mouse = NSEvent.mouseLocation
        let target = controllers.first { $0.screen.frame.contains(mouse) } ?? controllers.first
        target?.toggleFromHotKey()
    }

    // MARK: Menubalk

    private func updateStatusItem() {
        let wanted = Pref.bool(Pref.showMenuBarIcon)
        if wanted, statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.button?.image = NSImage(systemSymbolName: "capsule.fill", accessibilityDescription: "Island")
            let menu = NSMenu()
            menu.addItem(withTitle: "Open eiland (⌃⌥Spatie)", action: #selector(openIslandFromMenu), keyEquivalent: "").target = self
            menu.addItem(withTitle: "Instellingen…", action: #selector(showSettings), keyEquivalent: ",").target = self
            menu.addItem(.separator())
            menu.addItem(withTitle: "Stop Island", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            item.menu = menu
            statusItem = item
        } else if !wanted, let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    @objc private func openIslandFromMenu() {
        controllers.first?.toggleFromHotKey()
    }

    @objc func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false)
            window.title = "Island-instellingen"
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(rootView: SettingsView().environmentObject(state))
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
