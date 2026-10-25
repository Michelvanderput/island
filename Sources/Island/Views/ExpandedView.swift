import SwiftUI

struct ExpandedView: View {
    @ObservedObject var vm: NotchViewModel
    @EnvironmentObject var state: IslandState
    @EnvironmentObject var nowPlaying: NowPlayingService
    @EnvironmentObject var lyrics: LyricsService
    @EnvironmentObject var tray: FileTrayStore

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: vm.geometry.notchSize.height)
            Group {
                switch vm.tab {
                case .home:
                    if nowPlaying.track != nil { PlayerView() } else { IdleHomeView() }
                case .lyrics:
                    LyricsView()
                case .tray:
                    TrayView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 16)
        }
        .foregroundStyle(.white)
    }

    private var header: some View {
        HStack(spacing: 0) {
            HStack(spacing: 2) {
                IconButton(symbol: "house.fill", size: 12, active: vm.tab == .home) { vm.tab = .home }
                if !lyrics.lines.isEmpty {
                    IconButton(symbol: "quote.bubble.fill", size: 12, active: vm.tab == .lyrics) { vm.tab = .lyrics }
                }
                IconButton(symbol: tray.items.isEmpty ? "tray" : "tray.full.fill", size: 12, active: vm.tab == .tray) { vm.tab = .tray }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 14)

            Color.clear.frame(width: vm.geometry.hasNotch ? vm.geometry.notchSize.width : 20)

            StatusCluster(openSettings: { state.openSettings?() })
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 14)
        }
    }
}

private struct StatusCluster: View {
    let openSettings: () -> Void
    @EnvironmentObject var battery: BatteryService
    @EnvironmentObject var weather: WeatherService
    @AppStorage(Pref.useFahrenheit) private var fahrenheit = false

    var body: some View {
        HStack(spacing: 10) {
            if let w = weather.weather {
                HStack(spacing: 4) {
                    Image(systemName: w.symbol).symbolRenderingMode(.multicolor)
                    Text(WeatherService.format(w.temperature))
                }
                .id(fahrenheit)
            }
            if battery.hasBattery {
                HStack(spacing: 4) {
                    Text("\(battery.level)%")
                    Image(systemName: batterySymbol(level: battery.level, charging: battery.isCharging))
                        .foregroundStyle(battery.level <= 20 && !battery.isPluggedIn ? Color.red : (battery.isCharging ? Color.green : Color.white))
                }
            }
            IconButton(symbol: "gearshape.fill", size: 11, action: openSettings)
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(.white.opacity(0.8))
    }
}

// MARK: Speler

struct PlayerView: View {
    @EnvironmentObject var state: IslandState
    @EnvironmentObject var nowPlaying: NowPlayingService
    @EnvironmentObject var lyrics: LyricsService

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ArtworkView(image: nowPlaying.artwork, size: 104, radius: 14)
                .shadow(color: Color(nsColor: state.accentColor).opacity(0.35), radius: 14)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(nowPlaying.track?.title ?? "")
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                        Text(nowPlaying.track?.artist ?? "")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    Spacer()
                    WaveformView(isPlaying: nowPlaying.isPlaying, color: Color(nsColor: state.accentColor), maxHeight: 16)
                        .padding(.top, 2)
                }

                CurrentLyricLine()
                    .frame(height: 18, alignment: .leading)
                    .padding(.top, 4)

                Spacer(minLength: 4)
                ScrubberView()
                ControlsView()
                    .padding(.top, 2)
            }
        }
    }
}

struct CurrentLyricLine: View {
    @EnvironmentObject var nowPlaying: NowPlayingService
    @EnvironmentObject var lyrics: LyricsService

    var body: some View {
        if lyrics.lines.isEmpty {
            Color.clear
        } else {
            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                let index = lyrics.index(at: nowPlaying.currentPosition(at: context.date))
                Text(index.map { lyrics.lines[$0].text } ?? "♪")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .id(index ?? -1)
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                    .animation(.easeOut(duration: 0.25), value: index)
            }
        }
    }
}

struct ScrubberView: View {
    @EnvironmentObject var nowPlaying: NowPlayingService
    @State private var dragValue: Double?
    @State private var hovering = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let duration = max(nowPlaying.track?.duration ?? 0, 1)
            let position = dragValue ?? nowPlaying.currentPosition(at: context.date)
            VStack(spacing: 3) {
                GeometryReader { geo in
                    let width = geo.size.width
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.18))
                        Capsule().fill(Color.white)
                            .frame(width: max(0, min(width, width * position / duration)))
                    }
                    .frame(height: dragValue != nil || hovering ? 7 : 4)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onHover { hovering = $0 }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                dragValue = max(0, min(1, value.location.x / max(width, 1))) * duration
                            }
                            .onEnded { value in
                                let target = max(0, min(1, value.location.x / max(width, 1))) * duration
                                nowPlaying.seek(to: target)
                                dragValue = nil
                            }
                    )
                    .animation(.easeOut(duration: 0.15), value: dragValue != nil || hovering)
                }
                .frame(height: 12)

                HStack {
                    Text(formatTime(position))
                    Spacer()
                    Text("-" + formatTime(duration - position))
                }
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}

struct ControlsView: View {
    @EnvironmentObject var nowPlaying: NowPlayingService

    var body: some View {
        HStack(spacing: 22) {
            if let source = nowPlaying.source {
                Text(source.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 70, alignment: .leading)
            }
            Spacer(minLength: 0)
            IconButton(symbol: "backward.fill", size: 15) { nowPlaying.previous() }
            IconButton(symbol: nowPlaying.isPlaying ? "pause.fill" : "play.fill", size: 20) { nowPlaying.playPause() }
            IconButton(symbol: "forward.fill", size: 15) { nowPlaying.next() }
            Spacer(minLength: 0)
            Color.clear.frame(width: 70)
        }
    }
}

// MARK: Rust-scherm

struct IdleHomeView: View {
    @EnvironmentObject var battery: BatteryService
    @EnvironmentObject var weather: WeatherService
    @EnvironmentObject var bluetooth: BluetoothService
    @AppStorage(Pref.useFahrenheit) private var fahrenheit = false

    var body: some View {
        HStack(spacing: 0) {
            TimelineView(.everyMinute) { context in
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.date, format: .dateTime.hour().minute())
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                    Text(context.date, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            divider

            Group {
                if let w = weather.weather {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: w.symbol).symbolRenderingMode(.multicolor)
                                .font(.system(size: 22))
                            Text(WeatherService.format(w.temperature))
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                        }
                        Text(w.summary + (w.place.isEmpty ? "" : " · \(w.place)"))
                            .font(.system(size: 11, weight: .medium)).lineLimit(1)
                            .foregroundStyle(.white.opacity(0.6))
                        Text("H \(WeatherService.format(w.high))  L \(WeatherService.format(w.low))")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.45))
                    }
                    .id(fahrenheit)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: "cloud.sun").font(.system(size: 22))
                        Text(weather.locationDenied ? "Stel een stad in bij Instellingen" : "Weer laden…")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            divider

            VStack(alignment: .leading, spacing: 8) {
                if battery.hasBattery {
                    HStack(spacing: 8) {
                        BatteryRing(level: battery.level, size: 22)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(battery.level)%").font(.system(size: 14, weight: .semibold, design: .rounded))
                            Text(battery.isCharging ? "Laadt op" : (battery.isPluggedIn ? "Aangesloten" : (battery.isLowPowerMode ? "Energiebesparing" : "Mac")))
                                .font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                ForEach(bluetooth.connected.prefix(2)) { device in
                    HStack(spacing: 8) {
                        Image(systemName: device.symbol).font(.system(size: 16)).frame(width: 22)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(device.battery.headline.map { "\($0)%" } ?? "Verbonden")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                            Text(device.name).font(.system(size: 10)).lineLimit(1).foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1).padding(.vertical, 10).padding(.horizontal, 14)
    }
}

// MARK: Songtekst

struct LyricsView: View {
    @EnvironmentObject var nowPlaying: NowPlayingService
    @EnvironmentObject var lyrics: LyricsService

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let current = lyrics.index(at: nowPlaying.currentPosition(at: context.date)) ?? -1
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(lyrics.lines) { line in
                            Text(line.text.isEmpty ? "♪" : line.text)
                                .font(.system(size: line.id == current ? 17 : 15, weight: .bold))
                                .foregroundStyle(.white.opacity(line.id == current ? 1 : (line.id < current ? 0.3 : 0.45)))
                                .id(line.id)
                                .onTapGesture { nowPlaying.seek(to: line.time) }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 40)
                }
                .onChange(of: current) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(newValue, anchor: .center) }
                }
                .onAppear { proxy.scrollTo(current, anchor: .center) }
                .mask(LinearGradient(colors: [.clear, .black, .black, .clear], startPoint: .top, endPoint: .bottom))
            }
        }
    }
}

// MARK: Lade

struct TrayView: View {
    @EnvironmentObject var tray: FileTrayStore

    var body: some View {
        if tray.items.isEmpty {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .overlay {
                    VStack(spacing: 6) {
                        Image(systemName: "tray.and.arrow.down.fill").font(.system(size: 22))
                        Text("Sleep bestanden hierheen").font(.system(size: 12, weight: .medium))
                        Text("Ze blijven hier klaarliggen tot je ze ergens anders neerzet.")
                            .font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                    }
                    .foregroundStyle(.white.opacity(0.75))
                }
        } else {
            HStack(spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(tray.items) { item in
                            TrayItemView(item: item)
                        }
                    }
                    .padding(.vertical, 4)
                }
                VStack(spacing: 6) {
                    IconButton(symbol: "airplayaudio", size: 13) { tray.airDrop(tray.items) }
                        .help("Alles via AirDrop delen")
                    IconButton(symbol: "trash", size: 13) { tray.clear() }
                        .help("Lade leegmaken")
                }
            }
        }
    }
}

private struct TrayItemView: View {
    let item: TrayItem
    @EnvironmentObject var tray: FileTrayStore
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: item.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)
            Text(item.name)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
        }
        .frame(width: 78, height: 92)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(hovering ? 0.1 : 0.04)))
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button { tray.remove(item) } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(3)
            }
        }
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { tray.open(item) }
        .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
        .contextMenu {
            Button("Open") { tray.open(item) }
            Button("Toon in Finder") { tray.reveal(item) }
            Button("Deel via AirDrop") { tray.airDrop([item]) }
            Divider()
            Button("Verwijder uit lade") { tray.remove(item) }
        }
        .help(item.name)
    }
}
