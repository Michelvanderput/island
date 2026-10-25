import SwiftUI

struct LockScreenView: View {
    @ObservedObject var controller: LockScreenController
    @EnvironmentObject var state: IslandState
    @EnvironmentObject var nowPlaying: NowPlayingService
    @AppStorage(Pref.lockScreenLyrics) private var showLyrics = true
    @AppStorage(Pref.lockScreenWidgets) private var showWidgets = true
    @AppStorage(Pref.lockScreenArtworkScale) private var artworkScale = 1.0
    @State private var showOutputs = false

    var body: some View {
        GeometryReader { geo in
            let artSize = min(geo.size.height * 0.42, 480) * artworkScale
            ZStack {
                if controller.isPreview {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .onTapGesture { controller.endPreview() }
                }
                if controller.isLocked {
                    VStack(spacing: 22) {
                        Spacer().frame(height: geo.size.height * 0.29)
                        if nowPlaying.track != nil {
                            ZStack {
                                if showOutputs {
                                    AudioOutputList(onSelect: { withAnimation { showOutputs = false } })
                                        .padding(18)
                                        .frame(width: artSize, height: artSize)
                                        .background(GlassBackground(image: nowPlaying.artwork, radius: 22))
                                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                } else {
                                    ArtworkView(image: nowPlaying.artwork, size: artSize, radius: 18)
                                        .shadow(color: .black.opacity(0.35), radius: 30, y: 12)
                                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                }
                            }
                            .frame(width: artSize, height: artSize)

                            LockPlayerCard(showOutputs: $showOutputs)
                                .frame(width: max(300, min(340, artSize * 0.75)))

                            if showLyrics {
                                CurrentLyricLine(fontSize: 18)
                                    .multilineTextAlignment(.center)
                                    .frame(width: artSize * 1.4, height: 26)
                                    .shadow(color: .black.opacity(0.5), radius: 6)
                            }
                        }
                        if showWidgets {
                            LockWidgetsRow()
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.3), value: nowPlaying.track != nil)
    }
}

/// 'Glas' dat niet afhankelijk is van wat er achter het venster zit: de vervaagde hoes, getint.
struct GlassBackground: View {
    let image: NSImage?
    var radius: CGFloat = 22

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 40)
                    .saturation(1.3)
            }
            Color.black.opacity(image == nil ? 0.55 : 0.35)
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.08)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
    }
}

private struct LockPlayerCard: View {
    @Binding var showOutputs: Bool
    @EnvironmentObject var state: IslandState
    @EnvironmentObject var nowPlaying: NowPlayingService
    @EnvironmentObject var audio: AudioOutputService
    @AppStorage(Pref.showFavorite) private var showFavorite = true

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                VStack(spacing: 1) {
                    Text(nowPlaying.track?.title ?? "")
                        .font(.system(size: 13, weight: .semibold))
                    Text(nowPlaying.track?.artist ?? "")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .lineLimit(1)
                .padding(.horizontal, 36)
                HStack {
                    Spacer()
                    WaveformView(isPlaying: nowPlaying.isPlaying, color: .white.opacity(0.7), maxHeight: 10)
                }
            }
            ScrubberView(inlineTimes: true)
            HStack {
                if showFavorite, let favorite = nowPlaying.isFavorite {
                    IconButton(symbol: favorite ? "heart.fill" : "heart", size: 15) { nowPlaying.toggleFavorite() }
                } else {
                    Color.clear.frame(width: 29, height: 25)
                }
                Spacer()
                IconButton(symbol: "backward.fill", size: 16) { nowPlaying.previous() }
                Spacer()
                IconButton(symbol: nowPlaying.isPlaying ? "pause.fill" : "play.fill", size: 22) { nowPlaying.playPause() }
                Spacer()
                IconButton(symbol: "forward.fill", size: 16) { nowPlaying.next() }
                Spacer()
                IconButton(symbol: audio.current?.symbol ?? "headphones", size: 15, active: showOutputs) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showOutputs.toggle() }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(GlassBackground(image: nowPlaying.artwork, radius: 24))
    }
}

private struct LockWidgetsRow: View {
    @EnvironmentObject var battery: BatteryService
    @EnvironmentObject var weather: WeatherService
    @EnvironmentObject var bluetooth: BluetoothService

    var body: some View {
        HStack(spacing: 10) {
            if let w = weather.weather {
                chip {
                    Image(systemName: w.symbol).symbolRenderingMode(.multicolor)
                    Text(WeatherService.format(w.temperature))
                }
            }
            if battery.hasBattery {
                chip {
                    BatteryRing(level: battery.level, size: 14)
                    Text("\(battery.level)%")
                    if battery.isCharging { Image(systemName: "bolt.fill").foregroundStyle(Color.green) }
                }
            }
            ForEach(bluetooth.connected.prefix(2)) { device in
                chip {
                    Image(systemName: device.symbol)
                    Text(device.battery.headline.map { "\($0)%" } ?? device.name)
                }
            }
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded))
    }

    private func chip<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 6) { content() }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.black.opacity(0.35)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
    }
}

/// Lijst met audio-uitgangen plus volume; gebruikt in de notch en op het vergrendelscherm.
struct AudioOutputList: View {
    var onSelect: () -> Void = {}
    @EnvironmentObject var audio: AudioOutputService

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: audio.volume == 0 ? "speaker.slash.fill" : "speaker.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
                VolumeSlider(value: Binding(get: { Double(audio.volume) }, set: { audio.setVolume(Float($0)) }))
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(audio.devices) { device in
                        Button {
                            audio.select(device)
                            onSelect()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: device.symbol)
                                    .font(.system(size: 14))
                                    .frame(width: 22)
                                Text(device.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                Spacer()
                                if device.id == audio.currentID {
                                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color.white.opacity(device.id == audio.currentID ? 0.16 : 0.05)))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .foregroundStyle(.white)
    }
}

struct VolumeSlider: View {
    @Binding var value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.18))
                Capsule().fill(Color.white).frame(width: geo.size.width * value)
            }
            .frame(height: 5)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                value = max(0, min(1, g.location.x / max(geo.size.width, 1)))
            })
        }
        .frame(height: 14)
    }
}
