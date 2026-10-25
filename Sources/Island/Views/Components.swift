import SwiftUI

struct ArtworkView: View {
    let image: NSImage?
    let size: CGFloat
    var radius: CGFloat = 10

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// Geanimeerde equalizer-balkjes; staat stil (en kost niets) als er niets speelt.
struct WaveformView: View {
    let isPlaying: Bool
    var color: Color = .white
    var maxHeight: CGFloat = 16

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { i in
                    let speed = 5.0 + Double(i) * 1.7
                    let phase = sin(t * speed + Double(i) * 1.3) * 0.5 + 0.5
                    Capsule()
                        .fill(color)
                        .frame(width: 3, height: isPlaying ? max(3, maxHeight * (0.25 + 0.75 * phase)) : 3)
                }
            }
            .frame(height: maxHeight)
        }
    }
}

struct BatteryRing: View {
    let level: Int
    var size: CGFloat = 16

    private var color: Color { level <= 20 ? .red : .green }

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.2), lineWidth: 2.2)
            Circle()
                .trim(from: 0, to: CGFloat(level) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

struct IconButton: View {
    let symbol: String
    var size: CGFloat = 14
    var active = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(active ? Color.white : Color.white.opacity(hovering ? 0.9 : 0.55))
                .frame(width: size + 14, height: size + 10)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(active ? 0.16 : (hovering ? 0.08 : 0)))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

func formatTime(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let s = Int(seconds.rounded(.down))
    return String(format: "%d:%02d", s / 60, s % 60)
}

/// Lijst met audio-uitgangen plus volume; gebruikt in de uitgeklapte notch.
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
