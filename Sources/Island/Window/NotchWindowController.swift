import AppKit
import SwiftUI

final class NotchPanel: NSPanel {
    init(frame: NSRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        ignoresMouseEvents = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Plaatst het eiland bovenaan het scherm en regelt openen (aanwijzen, klikken of sneltoets) en sluiten.
final class NotchWindowController: NSObject {
    let screen: NSScreen
    private let panel: NotchPanel
    private let viewModel: NotchViewModel
    private var monitors: [Any] = []
    private var expandWork: DispatchWorkItem?
    private var collapseWork: DispatchWorkItem?
    /// Geopend met de sneltoets: blijft open tot je erin en weer uit gaat, of buiten klikt.
    private var pinned = false

    var isExpanded: Bool { viewModel.isExpanded }

    init(screen: NSScreen, state: IslandState) {
        self.screen = screen
        let geometry = NotchGeometry(screen: screen)
        viewModel = NotchViewModel(geometry: geometry, state: state)

        let size = geometry.windowSize
        let frame = NSRect(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height,
                           width: size.width, height: size.height)
        panel = NotchPanel(frame: frame)
        super.init()

        let root = IslandView(vm: viewModel)
            .environmentObject(state)
            .environmentObject(state.nowPlaying)
            .environmentObject(state.lyrics)
            .environmentObject(state.battery)
            .environmentObject(state.bluetooth)
            .environmentObject(state.weather)
            .environmentObject(state.tray)
            .environmentObject(state.audio)
        let host = FirstMouseHostingView(rootView: root)
        host.sizingOptions = []
        host.frame = NSRect(origin: .zero, size: size)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()

        installMonitors()
    }

    func close() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        panel.orderOut(nil)
        panel.close()
    }

    func toggleFromHotKey() {
        if viewModel.isExpanded {
            collapse()
        } else {
            pinned = true
            expand(tab: nil)
        }
    }

    // MARK: Muis

    private func installMonitors() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseUp, .leftMouseDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handle(event, isLocal: false)
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handle(event, isLocal: true)
            return event
        }) {
            monitors.append(local)
        }
    }

    private func islandRect(_ size: CGSize) -> NSRect {
        NSRect(x: screen.frame.midX - size.width / 2 - viewModel.geometry.topRadius,
               y: screen.frame.maxY - size.height,
               width: size.width + viewModel.geometry.topRadius * 2,
               height: size.height)
    }

    private func handle(_ event: NSEvent, isLocal: Bool) {
        let location = NSEvent.mouseLocation
        let isDragging = event.type == .leftMouseDragged

        if viewModel.isExpanded {
            let inside = islandRect(viewModel.geometry.expandedSize).insetBy(dx: -12, dy: -12).contains(location)
            if pinned {
                if inside {
                    pinned = false
                } else if event.type == .leftMouseDown, !isLocal {
                    collapse()
                }
                return
            }
            if inside || NSEvent.pressedMouseButtons != 0 {
                collapseWork?.cancel()
                collapseWork = nil
            } else if collapseWork == nil {
                let work = DispatchWorkItem { [weak self] in self?.collapse() }
                collapseWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
            }
            return
        }

        // Ingeklapt: de hot zone is het zichtbare eiland, met wat marge.
        var hot = islandRect(viewModel.currentSize).insetBy(dx: -6, dy: -6)
        if isDragging { hot = hot.insetBy(dx: -30, dy: -20) }
        guard hot.contains(location) else {
            expandWork?.cancel()
            expandWork = nil
            return
        }

        if isDragging {
            let types = NSPasteboard(name: .drag).types ?? []
            guard types.contains(.fileURL) else { return }
            expand(tab: .tray)
            return
        }

        if OpenMode.current == .click {
            if event.type == .leftMouseDown { expand(tab: nil) }
            return
        }

        guard expandWork == nil, NSEvent.pressedMouseButtons == 0 else { return }
        let delay = UserDefaults.standard.double(forKey: Pref.hoverDelay)
        let work = DispatchWorkItem { [weak self] in
            self?.expandWork = nil
            guard let self, self.islandRect(self.viewModel.currentSize).insetBy(dx: -6, dy: -6).contains(NSEvent.mouseLocation) else { return }
            self.expand(tab: nil)
        }
        expandWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func expand(tab: IslandTab?) {
        guard !viewModel.isExpanded else { return }
        expandWork?.cancel()
        expandWork = nil
        panel.ignoresMouseEvents = false
        if Pref.bool(Pref.hapticFeedback) {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            viewModel.prepareForOpening(tab: tab)
            viewModel.isExpanded = true
        }
    }

    private func collapse() {
        collapseWork?.cancel()
        collapseWork = nil
        pinned = false
        guard viewModel.isExpanded else { return }
        panel.ignoresMouseEvents = true
        withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
            viewModel.isExpanded = false
            viewModel.showOutputs = false
        }
        if viewModel.tab == .tray, viewModel.state.tray.items.isEmpty { viewModel.tab = .home }
    }
}
