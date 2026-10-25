import SwiftUI
import UniformTypeIdentifiers

struct IslandView: View {
    @ObservedObject var vm: NotchViewModel
    @EnvironmentObject var state: IslandState
    @EnvironmentObject var nowPlaying: NowPlayingService
    @EnvironmentObject var tray: FileTrayStore
    @AppStorage(Pref.compactMusic) private var compactMusic = true

    var body: some View {
        let mode = vm.mode
        let size = vm.size(for: mode)
        let expanded = mode == .expanded
        let shape = NotchShape(topRadius: vm.geometry.topRadius, bottomRadius: expanded ? 28 : vm.geometry.notchSize.height * 0.32)

        ZStack(alignment: .top) {
            content(for: mode)
                .frame(width: size.width, height: size.height, alignment: .top)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
        }
        .frame(width: size.width, height: size.height)
        .padding(.horizontal, vm.geometry.topRadius)
        .background(shape.fill(Color.black))
        .clipShape(shape)
        .overlay {
            if vm.isDropTargeted {
                shape.stroke(Color.white.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
        }
        .shadow(color: .black.opacity(expanded ? 0.45 : 0), radius: 14, y: 6)
        .opacity(mode == .idle && !vm.geometry.hasNotch ? 0 : 1)
        .onDrop(of: [UTType.fileURL], isTargeted: $vm.isDropTargeted) { providers in
            accept(providers)
        }
        .contextMenu {
            Button("Instellingen…") { state.openSettings?() }
            Button("Stop Island") { NSApp.terminate(nil) }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: mode)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func content(for mode: IslandMode) -> some View {
        switch mode {
        case .idle:
            Color.clear
        case .music:
            CompactMusicView(wing: vm.musicWing, notchHeight: vm.geometry.notchSize.height)
        case .hud(let hud):
            HUDView(hud: hud, wing: vm.hudWing, notchHeight: vm.geometry.notchSize.height)
        case .expanded:
            ExpandedView(vm: vm)
        }
    }

    private func accept(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            accepted = true
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async {
                    tray.add([url])
                    vm.tab = .tray
                }
            }
        }
        return accepted
    }
}

// MARK: Compact

struct CompactMusicView: View {
    let wing: CGFloat
    let notchHeight: CGFloat
    @EnvironmentObject var state: IslandState
    @EnvironmentObject var nowPlaying: NowPlayingService

    var body: some View {
        HStack(spacing: 0) {
            ArtworkView(image: nowPlaying.artwork, size: notchHeight - 10, radius: 5)
                .frame(width: wing)
            Spacer(minLength: 0)
            WaveformView(isPlaying: nowPlaying.isPlaying, color: Color(nsColor: state.accentColor), maxHeight: notchHeight * 0.45)
                .frame(width: wing)
        }
        .frame(maxHeight: .infinity)
    }
}

struct HUDView: View {
    let hud: HUD
    let wing: CGFloat
    let notchHeight: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            left.frame(width: wing)
            Spacer(minLength: 0)
            right.frame(width: wing)
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder private var left: some View {
        switch hud {
        case .charging(_, let plugged):
            Image(systemName: plugged ? "bolt.fill" : "powerplug.fill")
                .foregroundStyle(plugged ? Color.green : Color.white)
        case .lowBattery:
            Image(systemName: "battery.25")
                .foregroundStyle(.red)
        case .bluetooth(let info, _):
            Image(systemName: info.symbol)
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder private var right: some View {
        switch hud {
        case .charging(let level, let plugged):
            HStack(spacing: 4) {
                Text("\(level)%")
                Image(systemName: batterySymbol(level: level, charging: plugged))
            }
            .foregroundStyle(plugged ? Color.green : Color.white)
        case .lowBattery(let level):
            Text("\(level)%").foregroundStyle(.red)
        case .bluetooth(let info, let connected):
            if !connected {
                Text("Los").foregroundStyle(.secondary)
            } else if let level = info.battery.headline {
                HStack(spacing: 5) {
                    BatteryRing(level: level, size: 14)
                    Text("\(level)%")
                }
            } else {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
    }
}

func batterySymbol(level: Int, charging: Bool) -> String {
    if charging { return "battery.100.bolt" }
    switch level {
    case ..<13: return "battery.0"
    case ..<38: return "battery.25"
    case ..<63: return "battery.50"
    case ..<88: return "battery.75"
    default: return "battery.100"
    }
}
