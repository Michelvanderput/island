import AppKit
import SwiftUI

/// Toont de speler en widgets op het vergrendelscherm.
final class LockScreenController: ObservableObject {
    @Published private(set) var isLocked = false
    @Published private(set) var isPreview = false

    private let state: IslandState
    private var panel: NSPanel?
    private var observers: [NSObjectProtocol] = []

    init(state: IslandState) {
        self.state = state
    }

    func start() {
        let dnc = DistributedNotificationCenter.default()
        observers.append(dnc.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.locked()
        })
        observers.append(dnc.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.unlocked()
        })
    }

    /// Laat de vergrendelscherm-weergave even op het bureaublad zien (via Instellingen).
    func preview() {
        isPreview = true
        locked(force: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            if self?.isPreview == true { self?.endPreview() }
        }
    }

    func endPreview() {
        guard isPreview else { return }
        unlocked()
    }

    private func locked(force: Bool = false) {
        guard force || Pref.bool(Pref.lockScreenEnabled) else { return }
        let panel = self.panel ?? makePanel()
        guard let panel else { return }
        if let screen = targetScreen() { panel.setFrame(screen.frame, display: false) }
        isLocked = true
        panel.ignoresMouseEvents = false
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            panel.animator().alphaValue = 1
        }
    }

    private func unlocked() {
        guard let panel, isLocked else { return }
        // Een echte ontgrendeling maakt ook een voorbeeld af; een voorbeeld laat een echte vergrendeling staan.
        panel.ignoresMouseEvents = true
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.isLocked = false
            self?.isPreview = false
        })
    }

    private func targetScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func makePanel() -> NSPanel? {
        guard let screen = targetScreen() else { return nil }
        let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.alphaValue = 0
        panel.ignoresMouseEvents = true

        let root = LockScreenView(controller: self)
            .environmentObject(state)
            .environmentObject(state.nowPlaying)
            .environmentObject(state.lyrics)
            .environmentObject(state.battery)
            .environmentObject(state.bluetooth)
            .environmentObject(state.weather)
            .environmentObject(state.audio)
        let host = FirstMouseHostingView(rootView: root)
        host.sizingOptions = []
        host.frame = NSRect(origin: .zero, size: screen.frame.size)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        panel.setFrame(screen.frame, display: false)
        panel.orderFrontRegardless()

        if !SkyLight.shared.delegate(panel) {
            NSLog("Island: SkyLight niet beschikbaar, vergrendelscherm-weergave alleen als voorbeeld")
        }
        self.panel = panel
        return panel
    }
}
