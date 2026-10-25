import AppKit
import Combine

enum MediaSource: String {
    case spotify = "com.spotify.client"
    case music = "com.apple.Music"

    var appName: String { self == .spotify ? "Spotify" : "Music" }
    var displayName: String { self == .spotify ? "Spotify" : "Apple Music" }

    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: rawValue).isEmpty
    }
}

struct Track: Equatable {
    var title: String
    var artist: String
    var album: String
    var duration: Double

    var key: String { "\(title)|\(artist)|\(album)" }
}

/// Volgt Spotify en Apple Music via hun distributed notifications (event driven, geen polling)
/// en bedient ze via AppleScript. Scripts draaien op een eigen queue zodat de UI nooit hapert.
final class NowPlayingService: ObservableObject {
    @Published private(set) var track: Track?
    @Published private(set) var isPlaying = false
    @Published private(set) var artwork: NSImage?
    @Published private(set) var source: MediaSource?
    /// Alleen Apple Music kent 'favoriet'; voor Spotify blijft dit nil.
    @Published private(set) var isFavorite: Bool?

    private var position: Double = 0
    private var positionDate = Date()
    private var artworkKey: String?
    private let scriptQueue = DispatchQueue(label: "island.applescript", qos: .userInitiated)
    private var observers: [NSObjectProtocol] = []

    func start() {
        let dnc = DistributedNotificationCenter.default()
        observers.append(dnc.addObserver(forName: Notification.Name("com.spotify.client.PlaybackStateChanged"), object: nil, queue: .main) { [weak self] note in
            self?.handle(note, from: .spotify)
        })
        observers.append(dnc.addObserver(forName: Notification.Name("com.apple.Music.playerInfo"), object: nil, queue: .main) { [weak self] note in
            self?.handle(note, from: .music)
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let self, app.bundleIdentifier == self.source?.rawValue else { return }
            self.clear()
        })

        // Begintoestand: vraag draaiende spelers één keer uit.
        for src in [MediaSource.spotify, .music] where src.isRunning {
            refresh(src)
        }
    }

    /// Na het wijzigen van de voorkeursspeler: opnieuw kijken wat er speelt.
    func reload() {
        if let current = source, !PreferredPlayer.current.allows(current) { clear() }
        for src in [MediaSource.spotify, .music] where src.isRunning {
            refresh(src)
        }
    }

    func currentPosition(at date: Date = Date()) -> Double {
        guard let track else { return 0 }
        let p = isPlaying ? position + date.timeIntervalSince(positionDate) : position
        return max(0, track.duration > 0 ? min(p, track.duration) : p)
    }

    // MARK: Bediening

    func playPause() {
        setPosition(currentPosition())
        isPlaying.toggle()
        run("playpause")
    }

    func toggleFavorite() {
        guard source == .music, let current = isFavorite else { return }
        isFavorite = !current
        let value = current ? "false" : "true"
        scriptQueue.async {
            let script = """
            tell application "Music"
                try
                    set favorited of current track to \(value)
                on error
                    set loved of current track to \(value)
                end try
            end tell
            """
            _ = Self.execute(script)
        }
    }

    func next() { run("next track", refreshAfter: true) }
    func previous() { run("previous track", refreshAfter: true) }

    func seek(to seconds: Double) {
        setPosition(seconds)
        let value = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), seconds)
        run("set player position to \(value)")
    }

    // MARK: Intern

    private func setPosition(_ p: Double) {
        position = p
        positionDate = Date()
    }

    private func clear() {
        track = nil
        isPlaying = false
        artwork = nil
        artworkKey = nil
        source = nil
        isFavorite = nil
    }

    private func handle(_ note: Notification, from src: MediaSource) {
        guard PreferredPlayer.current.allows(src) else { return }
        let info = note.userInfo ?? [:]
        let state = (info["Player State"] as? String) ?? ""
        if state == "Stopped" {
            if source == src { clear() }
            return
        }
        let playing = state == "Playing"
        // Een pauzerende speler neemt het niet over van een speler die wél speelt.
        if let current = source, current != src, isPlaying, !playing { return }

        source = src
        isPlaying = playing
        if let name = info["Name"] as? String {
            let durationMs = (info["Duration"] as? NSNumber) ?? (info["Total Time"] as? NSNumber)
            let newTrack = Track(
                title: name,
                artist: info["Artist"] as? String ?? "",
                album: info["Album"] as? String ?? "",
                duration: (durationMs?.doubleValue ?? 0) / 1000)
            if newTrack != track { track = newTrack }
        }
        if let pos = info["Playback Position"] as? NSNumber {
            setPosition(pos.doubleValue)
        }
        // Positie en hoes komen niet altijd mee in de notificatie.
        refresh(src)
    }

    private func refresh(_ src: MediaSource) {
        guard src.isRunning, PreferredPlayer.current.allows(src) else { return }
        let script: String
        switch src {
        case .spotify:
            script = """
            tell application "Spotify"
                set s to player state as string
                if s is "stopped" then return {s}
                set t to current track
                return {s, name of t, artist of t, album of t, (duration of t) / 1000, player position, artwork url of t, "none"}
            end tell
            """
        case .music:
            script = """
            tell application "Music"
                set s to player state as string
                if s is "stopped" then return {s}
                set t to current track
                set fav to "none"
                try
                    set fav to (favorited of t) as string
                on error
                    try
                        set fav to (loved of t) as string
                    end try
                end try
                return {s, name of t, artist of t, album of t, duration of t, player position, "", fav}
            end tell
            """
        }
        scriptQueue.async { [weak self] in
            guard let result = Self.execute(script), result.numberOfItems >= 1 else { return }
            let state = result.atIndex(1)?.stringValue ?? ""
            let favorite = result.numberOfItems >= 8 ? result.atIndex(8)?.stringValue : nil
            let parsed: (Track, Double, String)? = result.numberOfItems >= 7
                ? (Track(
                    title: result.atIndex(2)?.stringValue ?? "",
                    artist: result.atIndex(3)?.stringValue ?? "",
                    album: result.atIndex(4)?.stringValue ?? "",
                    duration: result.atIndex(5)?.doubleValue ?? 0),
                   result.atIndex(6)?.doubleValue ?? 0,
                   result.atIndex(7)?.stringValue ?? "")
                : nil
            DispatchQueue.main.async {
                guard let self else { return }
                if state == "stopped" {
                    if self.source == src { self.clear() }
                    return
                }
                let playing = state == "playing"
                if let current = self.source, current != src, self.isPlaying, !playing { return }
                guard let parsed else { return }
                let (t, pos, art) = parsed
                self.source = src
                self.isPlaying = playing
                if t != self.track { self.track = t }
                self.setPosition(pos)
                self.isFavorite = favorite == "true" ? true : (favorite == "false" ? false : nil)
                self.loadArtwork(for: t, source: src, url: art)
            }
        }
    }

    private func loadArtwork(for t: Track, source src: MediaSource, url: String) {
        guard artworkKey != t.key else { return }
        artworkKey = t.key
        artwork = nil
        switch src {
        case .spotify:
            guard let u = URL(string: url) else { return }
            URLSession.shared.dataTask(with: u) { [weak self] data, _, _ in
                guard let data, let img = NSImage(data: data) else { return }
                DispatchQueue.main.async {
                    if self?.artworkKey == t.key { self?.artwork = img }
                }
            }.resume()
        case .music:
            scriptQueue.async { [weak self] in
                let desc = Self.execute("tell application \"Music\" to get data of artwork 1 of current track")
                guard let data = desc?.data, let img = NSImage(data: data) else { return }
                DispatchQueue.main.async {
                    if self?.artworkKey == t.key { self?.artwork = img }
                }
            }
        }
    }

    private func run(_ command: String, refreshAfter: Bool = false) {
        guard let src = source, src.isRunning else { return }
        scriptQueue.async { [weak self] in
            _ = Self.execute("tell application \"\(src.appName)\" to \(command)")
            if refreshAfter {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self?.refresh(src) }
            }
        }
    }

    private static func execute(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error { NSLog("Island AppleScript: \(error)") }
        return result
    }
}
