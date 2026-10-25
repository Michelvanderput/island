import SwiftUI

enum IslandMode: Equatable {
    case idle
    case music(caption: Bool)
    case hud(HUD)
    case expanded
}

enum IslandTab: Hashable {
    case home, lyrics, tray
}

/// Toestand van één eiland (per scherm).
final class NotchViewModel: ObservableObject {
    let geometry: NotchGeometry
    let state: IslandState

    @Published var isExpanded = false
    @Published var tab: IslandTab = .home
    @Published var showOutputs = false
    @Published var isDropTargeted = false

    init(geometry: NotchGeometry, state: IslandState) {
        self.geometry = geometry
        self.state = state
    }

    var mode: IslandMode {
        if isExpanded { return .expanded }
        if let hud = state.hud { return .hud(hud) }
        if Pref.bool(Pref.compactMusic), state.nowPlaying.isPlaying, state.nowPlaying.track != nil {
            let caption = Pref.bool(Pref.lyricsInNotch) && !state.lyrics.lines.isEmpty
            return .music(caption: caption)
        }
        return .idle
    }

    /// Breedte van één 'vleugel' links of rechts van de notch.
    var musicWing: CGFloat { geometry.notchSize.height + 8 }
    var hudWing: CGFloat { 78 }
    /// Extra hoogte voor een regel tekst onder de notch (songtekst of nummerwissel).
    var captionHeight: CGFloat { 26 }

    func size(for mode: IslandMode) -> CGSize {
        let notch = geometry.notchSize
        switch mode {
        case .idle:
            return notch
        case .music(let caption):
            return caption
                ? CGSize(width: notch.width + hudWing * 2, height: notch.height + captionHeight)
                : CGSize(width: notch.width + musicWing * 2, height: notch.height)
        case .hud(.track):
            return CGSize(width: notch.width + hudWing * 2, height: notch.height + captionHeight)
        case .hud:
            return CGSize(width: notch.width + hudWing * 2, height: notch.height)
        case .expanded:
            return geometry.expandedSize
        }
    }

    var currentSize: CGSize { size(for: mode) }

    func select(_ newTab: IslandTab) {
        showOutputs = false
        tab = newTab
    }

    /// Kiest het tabblad bij openen, volgens de instelling 'Openen op'.
    func prepareForOpening(tab requested: IslandTab?) {
        showOutputs = false
        if let requested {
            tab = requested
            return
        }
        switch DefaultTab.current {
        case .home:
            tab = .home
        case .lyrics:
            tab = state.lyrics.lines.isEmpty ? .home : .lyrics
        case .last:
            if tab == .lyrics, state.lyrics.lines.isEmpty { tab = .home }
        }
    }
}
