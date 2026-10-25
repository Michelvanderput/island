import Foundation

struct LyricLine: Identifiable, Equatable {
    let id: Int
    let time: Double
    let text: String
}

/// Tijdgesynchroniseerde songteksten via LRCLib (gratis, geen sleutel nodig).
final class LyricsService: ObservableObject {
    @Published private(set) var lines: [LyricLine] = []
    @Published private(set) var isLoading = false

    private var currentKey: String?
    private var cache: [String: [LyricLine]] = [:]

    func load(_ track: Track?) {
        guard Pref.bool(Pref.lyricsEnabled), let track, !track.title.isEmpty else {
            currentKey = nil
            lines = []
            return
        }
        guard track.key != currentKey else { return }
        currentKey = track.key
        if let cached = cache[track.key] {
            lines = cached
            return
        }
        lines = []
        isLoading = true

        var comps = URLComponents(string: "https://lrclib.net/api/get")!
        comps.queryItems = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "album_name", value: track.album),
        ]
        if track.duration > 0 {
            comps.queryItems?.append(URLQueryItem(name: "duration", value: String(Int(track.duration.rounded()))))
        }
        fetch(comps.url!) { [weak self] parsed in
            if let parsed, !parsed.isEmpty {
                self?.finish(parsed, key: track.key)
            } else {
                self?.search(track)
            }
        }
    }

    func index(at position: Double) -> Int? {
        guard !lines.isEmpty else { return nil }
        var lo = 0, hi = lines.count - 1, found: Int?
        while lo <= hi {
            let mid = (lo + hi) / 2
            if lines[mid].time <= position + 0.2 { found = mid; lo = mid + 1 } else { hi = mid - 1 }
        }
        return found
    }

    private func search(_ track: Track) {
        var comps = URLComponents(string: "https://lrclib.net/api/search")!
        comps.queryItems = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist),
        ]
        var request = URLRequest(url: comps.url!)
        request.setValue("Island/1.0 (macOS notch app)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            let results = (data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [[String: Any]]) ?? []
            let synced = results.compactMap { $0["syncedLyrics"] as? String }.first
            let parsed = synced.map(Self.parse) ?? []
            DispatchQueue.main.async { self?.finish(parsed, key: track.key) }
        }.resume()
    }

    private func fetch(_ url: URL, completion: @escaping ([LyricLine]?) -> Void) {
        var request = URLRequest(url: url)
        request.setValue("Island/1.0 (macOS notch app)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, _, _ in
            let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
            let parsed = (json?["syncedLyrics"] as? String).map(Self.parse)
            DispatchQueue.main.async { completion(parsed) }
        }.resume()
    }

    private func finish(_ parsed: [LyricLine], key: String) {
        cache[key] = parsed
        guard key == currentKey else { return }
        isLoading = false
        lines = parsed
    }

    /// Leest LRC: "[mm:ss.xx] tekst".
    static func parse(_ lrc: String) -> [LyricLine] {
        var out: [(Double, String)] = []
        for raw in lrc.split(whereSeparator: \.isNewline) {
            var line = Substring(raw)
            var stamps: [Double] = []
            while line.hasPrefix("["), let close = line.firstIndex(of: "]") {
                let tag = line[line.index(after: line.startIndex)..<close]
                let parts = tag.split(separator: ":")
                if parts.count == 2, let m = Double(parts[0]), let s = Double(parts[1]) {
                    stamps.append(m * 60 + s)
                }
                line = line[line.index(after: close)...]
            }
            let text = line.trimmingCharacters(in: .whitespaces)
            for t in stamps { out.append((t, text)) }
        }
        return out.sorted { $0.0 < $1.0 }.enumerated().map { LyricLine(id: $0.offset, time: $0.element.0, text: $0.element.1) }
    }
}
