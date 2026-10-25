import SwiftUI

enum IslandMode: Equatable {
    case idle
    case music
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
    @Published var isDropTargeted = false

    init(geometry: NotchGeometry, state: IslandState) {
        self.geometry = geometry
        self.state = state
    }

    var mode: IslandMode {
        if isExpanded { return .expanded }
        if let hud = state.hud { return .hud(hud) }
        if Pref.bool(Pref.compactMusic), state.nowPlaying.isPlaying, state.nowPlaying.track != nil { return .music }
        return .idle
    }

    /// Breedte van één 'vleugel' links of rechts van de notch.
    var musicWing: CGFloat { geometry.notchSize.height + 8 }
    var hudWing: CGFloat { 78 }

    func size(for mode: IslandMode) -> CGSize {
        let notch = geometry.notchSize
        switch mode {
        case .idle: return notch
        case .music: return CGSize(width: notch.width + musicWing * 2, height: notch.height)
        case .hud: return CGSize(width: notch.width + hudWing * 2, height: notch.height)
        case .expanded: return geometry.expandedSize
        }
    }

    var currentSize: CGSize { size(for: mode) }
}
