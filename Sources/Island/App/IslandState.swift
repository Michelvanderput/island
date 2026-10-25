import AppKit
import Combine

/// Korte meldingen die de notch even laten uitzetten, zoals bij de Dynamic Island.
enum HUD: Equatable {
    case charging(level: Int, pluggedIn: Bool)
    case lowBattery(level: Int)
    case bluetooth(BluetoothDeviceInfo, connected: Bool)
    case track(Track)
}

/// Gedeelde toestand voor alle schermen: de services en de actieve melding.
final class IslandState: ObservableObject {
    let nowPlaying = NowPlayingService()
    let lyrics = LyricsService()
    let battery = BatteryService()
    let bluetooth = BluetoothService()
    let weather = WeatherService()
    let tray = FileTrayStore()
    let audio = AudioOutputService()

    @Published private(set) var hud: HUD?
    @Published private(set) var artworkColor: NSColor = .white

    /// Kleur voor golfvorm en gloed: uit de hoes, of wit als dat uit staat.
    var accentColor: NSColor { Pref.bool(Pref.artworkAccent) ? artworkColor : .white }

    var openSettings: (() -> Void)?
    /// Of er op dit moment een eiland open is (dan geen nummerwissel-melding).
    var isAnyIslandExpanded: () -> Bool = { false }

    private var hudWork: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()

    func start() {
        battery.onEvent = { [weak self] in self?.show($0) }
        bluetooth.onEvent = { [weak self] in self?.show($0) }

        nowPlaying.$track
            .removeDuplicates()
            .sink { [weak self] in self?.lyrics.load($0) }
            .store(in: &cancellables)

        // Nummerwissel: pas tonen zodra de nieuwe hoes binnen is (of na een halve seconde).
        nowPlaying.$track
            .removeDuplicates()
            .scan((nil, nil)) { (pair: (Track?, Track?), next: Track?) in (pair.1, next) }
            .compactMap { pair -> Track? in
                guard pair.0 != nil, let next = pair.1 else { return nil }
                return next
            }
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] track in
                guard let self, Pref.bool(Pref.trackChangeHUD), self.nowPlaying.isPlaying,
                      !self.isAnyIslandExpanded(), self.hud == nil else { return }
                self.show(.track(track), for: 2.5)
            }
            .store(in: &cancellables)

        nowPlaying.$artwork
            .map { $0?.averageColor ?? .white }
            .sink { [weak self] in self?.artworkColor = $0 }
            .store(in: &cancellables)

        nowPlaying.start()
        battery.start()
        bluetooth.start()
        weather.start()
        audio.start()
    }

    func show(_ hud: HUD, for seconds: Double = 3) {
        hudWork?.cancel()
        self.hud = hud
        let work = DispatchWorkItem { [weak self] in self?.hud = nil }
        hudWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
}

extension NSImage {
    /// Gemiddelde kleur, opgehelderd zodat hij op zwart altijd leesbaar is.
    var averageColor: NSColor? {
        guard let cg = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let ctx = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let color = NSColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255, blue: CGFloat(pixel[2]) / 255, alpha: 1)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.usingColorSpace(.deviceRGB)?.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return NSColor(hue: h, saturation: min(s, 0.7), brightness: max(b, 0.75), alpha: 1)
    }
}
