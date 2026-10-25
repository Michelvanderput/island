import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: IslandState

    var body: some View {
        TabView {
            GeneralSettings().tabItem { Label("Algemeen", systemImage: "gearshape") }
            NotchSettings().tabItem { Label("Notch", systemImage: "capsule.fill") }
            MediaSettings().tabItem { Label("Media", systemImage: "music.note") }
            LockScreenSettings().tabItem { Label("Vergrendelscherm", systemImage: "lock.fill") }
            WidgetSettings().tabItem { Label("Widgets", systemImage: "square.grid.2x2") }
            DiagnosticsView().tabItem { Label("Diagnose", systemImage: "waveform.path.ecg") }
        }
        .frame(width: 560, height: 520)
    }
}

private struct GeneralSettings: View {
    @AppStorage(Pref.showMenuBarIcon) private var showMenuBarIcon = true
    @AppStorage(Pref.displayMode) private var displayMode = DisplayMode.builtIn.rawValue
    @AppStorage(Pref.openMode) private var openMode = OpenMode.hover.rawValue
    @AppStorage(Pref.hoverDelay) private var hoverDelay = 0.15
    @AppStorage(Pref.hapticFeedback) private var haptics = true
    @AppStorage(Pref.hotKeyEnabled) private var hotKey = true
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section {
                Toggle("Start bij inloggen", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, value in LaunchAtLogin.set(value) }
                Toggle("Icoon in de menubalk", isOn: $showMenuBarIcon)
                Picker("Toon op", selection: $displayMode) {
                    ForEach(DisplayMode.allCases) { Text($0.label).tag($0.rawValue) }
                }
            } footer: {
                Text("Zonder menubalk-icoon open je deze instellingen via rechtsklik op het eiland.")
            }
            Section("Openen") {
                Picker("Open het eiland door", selection: $openMode) {
                    ForEach(OpenMode.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                if openMode == OpenMode.hover.rawValue {
                    LabeledContent("Vertraging") {
                        Slider(value: $hoverDelay, in: 0...0.6, step: 0.05) {
                            EmptyView()
                        } minimumValueLabel: { Text("0 s") } maximumValueLabel: { Text("0,6 s") }
                    }
                }
                Toggle("Sneltoets ⌃⌥Spatie opent en sluit het eiland", isOn: $hotKey)
                Toggle("Haptische feedback (trackpad)", isOn: $haptics)
            }
            Section("Toestemmingen") {
                permissionRow("Automatisering", detail: "Om Spotify en Muziek te bedienen", pane: "Privacy_Automation")
                permissionRow("Locatie", detail: "Voor het weer (globaal)", pane: "Privacy_LocationServices")
                permissionRow("Bluetooth", detail: "Voor AirPods-meldingen", pane: "Privacy_Bluetooth")
            }
            Section {
                HStack {
                    Text("Island 1.1")
                    Spacer()
                    Button("Standaardinstellingen…") { confirmReset = true }
                    Button("Stop Island") { NSApp.terminate(nil) }
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Alle instellingen terugzetten?", isPresented: $confirmReset) {
            Button("Zet terug", role: .destructive) { Pref.resetAll() }
        } message: {
            Text("De bestanden in je lade blijven staan.")
        }
    }

    private func permissionRow(_ title: String, detail: String, pane: String) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}

private struct NotchSettings: View {
    @EnvironmentObject var state: IslandState
    @AppStorage(Pref.expandedSize) private var expandedSize = ExpandedSize.standard.rawValue
    @AppStorage(Pref.defaultTab) private var defaultTab = DefaultTab.home.rawValue
    @AppStorage(Pref.trackChangeHUD) private var trackChangeHUD = true
    @AppStorage(Pref.lyricsInNotch) private var lyricsInNotch = false
    @AppStorage(Pref.artworkAccent) private var artworkAccent = true
    @AppStorage(Pref.compactMusic) private var compactMusic = true
    @AppStorage(Pref.trayCopyFiles) private var trayCopyFiles = false
    @AppStorage(Pref.trayClearOnQuit) private var trayClearOnQuit = false

    var body: some View {
        Form {
            Section("Uitgeklapt") {
                Picker("Grootte", selection: $expandedSize) {
                    ForEach(ExpandedSize.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                Picker("Openen op", selection: $defaultTab) {
                    ForEach(DefaultTab.allCases) { Text($0.label).tag($0.rawValue) }
                }
            }
            Section("Ingeklapt, tijdens afspelen") {
                Toggle("Hoes en golfvorm naast de notch", isOn: $compactMusic)
                Toggle("Meelopende songtekst onder de notch", isOn: $lyricsInNotch)
                    .disabled(!compactMusic)
                Toggle("Kort het nieuwe nummer tonen bij wisselen", isOn: $trackChangeHUD)
                Toggle("Kleur van de golfvorm uit de hoes halen", isOn: $artworkAccent)
            }
            Section {
                Toggle("Kopieer bestanden naar de lade", isOn: $trayCopyFiles)
                Toggle("Leeg de lade bij afsluiten", isOn: $trayClearOnQuit)
                HStack {
                    Text("\(state.tray.items.count) bestand(en) in de lade")
                    Spacer()
                    Button("Leegmaken") { state.tray.clear() }
                }
            } header: {
                Text("Bestandenlade")
            } footer: {
                Text("Met kopiëren blijven bestanden in de lade, ook als je het origineel verplaatst of weggooit. Island verwijdert alleen eigen kopieën, nooit je originelen.")
            }
        }
        .formStyle(.grouped)
    }
}

private struct MediaSettings: View {
    @EnvironmentObject var state: IslandState
    @AppStorage(Pref.preferredPlayer) private var preferredPlayer = PreferredPlayer.automatic.rawValue
    @AppStorage(Pref.lyricsEnabled) private var lyricsEnabled = true
    @AppStorage(Pref.showFavorite) private var showFavorite = true

    var body: some View {
        Form {
            Section("Muziek") {
                Picker("Speler", selection: $preferredPlayer) {
                    ForEach(PreferredPlayer.allCases) { Text($0.label).tag($0.rawValue) }
                }
                Toggle("Songteksten ophalen (via LRCLib)", isOn: $lyricsEnabled)
                    .onChange(of: lyricsEnabled) { _, _ in state.lyrics.load(state.nowPlaying.track) }
                Toggle("Hartje tonen (favoriet in Apple Music)", isOn: $showFavorite)
            }
            Section("Audio-uitgang") {
                AudioOutputSettingsList()
            }
            Section {
                Text("Island werkt met Spotify en Apple Music. Bij de eerste bediening vraagt macOS om toestemming voor automatisering.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct AudioOutputSettingsList: View {
    @EnvironmentObject var state: IslandState

    var body: some View {
        AudioOutputSettingsRows(audio: state.audio)
    }
}

private struct AudioOutputSettingsRows: View {
    @ObservedObject var audio: AudioOutputService

    var body: some View {
        LabeledContent("Volume") {
            Slider(value: Binding(get: { Double(audio.volume) }, set: { audio.setVolume(Float($0)) }), in: 0...1)
        }
        Picker("Uitgang", selection: Binding(get: { audio.currentID }, set: { id in
            if let device = audio.devices.first(where: { $0.id == id }) { audio.select(device) }
        })) {
            ForEach(audio.devices) { Label($0.name, systemImage: $0.symbol).tag($0.id) }
        }
    }
}

private struct LockScreenSettings: View {
    @EnvironmentObject var state: IslandState
    @AppStorage(Pref.lockScreenEnabled) private var enabled = true
    @AppStorage(Pref.lockScreenLyrics) private var lyrics = true
    @AppStorage(Pref.lockScreenWidgets) private var widgets = true
    @AppStorage(Pref.lockScreenArtworkScale) private var artworkScale = 1.0

    var body: some View {
        Form {
            Section {
                Toggle("Speler op het vergrendelscherm", isOn: $enabled)
                Toggle("Meelopende songtekst", isOn: $lyrics).disabled(!enabled)
                Toggle("Widgets: weer, batterij en AirPods", isOn: $widgets).disabled(!enabled)
                LabeledContent("Grootte van de hoes") {
                    Slider(value: $artworkScale, in: 0.6...1.2) {
                        EmptyView()
                    } minimumValueLabel: { Text("S") } maximumValueLabel: { Text("L") }
                }
                .disabled(!enabled)
            } footer: {
                Text("Op het vergrendelscherm zie je de hoes, een glazen speler met hartje en audio-uitgang, en eventueel de songtekst en widgets. Dit gebruikt een niet-openbare macOS-techniek; werkt die na een macOS-update niet meer, dan zie je gewoon niets.")
            }
            Section {
                Button("Voorbeeld tonen") { state.previewLockScreen?() }
            } footer: {
                Text("Toont de weergave een paar seconden over je bureaublad. Klik om te sluiten.")
            }
        }
        .formStyle(.grouped)
    }
}

private struct WidgetSettings: View {
    @EnvironmentObject var state: IslandState
    @AppStorage(Pref.weatherEnabled) private var weatherEnabled = true
    @AppStorage(Pref.weatherCity) private var weatherCity = ""
    @AppStorage(Pref.useFahrenheit) private var fahrenheit = false
    @AppStorage(Pref.batteryAlerts) private var batteryAlerts = true
    @AppStorage(Pref.lowBatteryThreshold) private var lowBatteryThreshold = 20
    @AppStorage(Pref.bluetoothAlerts) private var bluetoothAlerts = true
    @State private var cityDraft = ""

    var body: some View {
        Form {
            Section("Weer") {
                Toggle("Weer tonen", isOn: $weatherEnabled)
                    .onChange(of: weatherEnabled) { _, _ in state.weather.refresh() }
                HStack {
                    TextField("Stad (leeg = huidige locatie)", text: $cityDraft)
                        .onSubmit { weatherCity = cityDraft }
                    Button("Bewaar") { weatherCity = cityDraft }
                }
                Toggle("Fahrenheit", isOn: $fahrenheit)
            }
            Section("Meldingen in de notch") {
                Toggle("Opladen en lage batterij", isOn: $batteryAlerts)
                Picker("Waarschuw bij", selection: $lowBatteryThreshold) {
                    ForEach([30, 25, 20, 15, 10], id: \.self) { Text("\($0)%").tag($0) }
                }
                .disabled(!batteryAlerts)
                Toggle("AirPods en Bluetooth-audio", isOn: $bluetoothAlerts)
            }
            Section("Probeer") {
                HStack {
                    Button("Opladen") { state.show(.charging(level: state.battery.level, pluggedIn: true)) }
                    Button("Lage batterij") { state.show(.lowBattery(level: 10)) }
                    Button("AirPods") {
                        state.show(.bluetooth(BluetoothDeviceInfo(id: "demo", name: "AirPods Pro",
                                                                  battery: BluetoothBattery(left: 84, right: 80, caseLevel: 60)),
                                              connected: true))
                    }
                    if let track = state.nowPlaying.track {
                        Button("Nummer") { state.show(.track(track), for: 2.5) }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { cityDraft = weatherCity }
    }
}

private struct DiagnosticsView: View {
    @EnvironmentObject var state: IslandState
    @State private var copied = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            Form {
                Section("Live") {
                    LabeledContent("Geheugen", value: memoryFootprint())
                    LabeledContent("Speler", value: state.nowPlaying.source?.displayName ?? "—")
                    LabeledContent("Speelt af", value: state.nowPlaying.isPlaying ? "Ja" : "Nee")
                    LabeledContent("Songtekstregels", value: "\(state.lyrics.lines.count)")
                    LabeledContent("Batterij", value: state.battery.hasBattery ? "\(state.battery.level)%" : "—")
                    LabeledContent("Bluetooth-audio", value: state.bluetooth.connected.map(\.name).joined(separator: ", ").ifEmpty("—"))
                    LabeledContent("Weer", value: state.weather.weather.map { "\(WeatherService.format($0.temperature)) \($0.place)" } ?? "—")
                    LabeledContent("Schermen", value: "\(NSScreen.screens.count)")
                }
                Section {
                    Button(copied ? "Gekopieerd" : "Kopieer diagnose") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(report(), forType: .string)
                        copied = true
                    }
                } footer: {
                    Text("Er wordt niets verstuurd. Alleen songteksten (titel + artiest naar LRCLib) en het weer (Open-Meteo) gaan over het netwerk.")
                }
            }
            .formStyle(.grouped)
        }
    }

    private func report() -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        return """
        Island 1.1 — macOS \(os)
        Geheugen: \(memoryFootprint())
        Speler: \(state.nowPlaying.source?.displayName ?? "—"), speelt: \(state.nowPlaying.isPlaying)
        Schermen: \(NSScreen.screens.map { "\(Int($0.frame.width))x\(Int($0.frame.height)) notch=\($0.safeAreaInsets.top > 0)" }.joined(separator: ", "))
        """
    }
}

private func memoryFootprint() -> String {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    guard result == KERN_SUCCESS else { return "—" }
    return ByteCountFormatter.string(fromByteCount: Int64(info.phys_footprint), countStyle: .memory)
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}
