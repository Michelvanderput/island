import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controllers: [NotchWindowController] = []
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    let state = IslandState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Pref.registerDefaults()
        state.start()
        rebuildWindows()

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildWindows() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyPreferences() }
            .store(in: &cancellables)

        state.openSettings = { [weak self] in self?.showSettings() }
        applyPreferences()
    }

    private var lastAllDisplays: Bool?

    private func applyPreferences() {
        updateStatusItem()
        let all = Pref.bool(Pref.showOnAllDisplays)
        if lastAllDisplays != nil, lastAllDisplays != all { rebuildWindows() }
        lastAllDisplays = all
    }

    private func rebuildWindows() {
        controllers.forEach { $0.close() }
        controllers.removeAll()

        let screens: [NSScreen]
        if Pref.bool(Pref.showOnAllDisplays) {
            screens = NSScreen.screens
        } else {
            // Voorkeur: het ingebouwde scherm met notch, anders het hoofdscherm.
            let notched = NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
            screens = [notched ?? NSScreen.main ?? NSScreen.screens.first].compactMap { $0 }
        }
        controllers = screens.map { NotchWindowController(screen: $0, state: state) }
    }

    // MARK: Menubalk

    private func updateStatusItem() {
        let wanted = Pref.bool(Pref.showMenuBarIcon)
        if wanted, statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.button?.image = NSImage(systemSymbolName: "capsule.fill", accessibilityDescription: "Island")
            let menu = NSMenu()
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

    @objc func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 460),
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
