import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: IslandState

    @AppStorage(Pref.showMenuBarIcon) private var showMenuBarIcon = true
    @AppStorage(Pref.showOnAllDisplays) private var showOnAllDisplays = false
    @AppStorage(Pref.hoverDelay) private var hoverDelay = 0.15
    @AppStorage(Pref.hapticFeedback) private var haptics = true
    @AppStorage(Pref.compactMusic) private var compactMusic = true
    @AppStorage(Pref.lyricsEnabled) private var lyricsEnabled = true
    @AppStorage(Pref.weatherEnabled) private var weatherEnabled = true
    @AppStorage(Pref.weatherCity) private var weatherCity = ""
    @AppStorage(Pref.useFahrenheit) private var fahrenheit = false
    @AppStorage(Pref.batteryAlerts) private var batteryAlerts = true
    @AppStorage(Pref.bluetoothAlerts) private var bluetoothAlerts = true

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var cityDraft = ""

    var body: some View {
        TabView {
            general.tabItem { Label("Algemeen", systemImage: "gearshape") }
            media.tabItem { Label("Media", systemImage: "music.note") }
            widgets.tabItem { Label("Widgets", systemImage: "square.grid.2x2") }
            DiagnosticsView().tabItem { Label("Diagnose", systemImage: "waveform.path.ecg") }
        }
        .frame(width: 520, height: 440)
        .onAppear { cityDraft = weatherCity }
    }

    private var general: some View {
        Form {
            Section {
                Toggle("Start bij inloggen", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, value in LaunchAtLogin.set(value) }
                Toggle("Icoon in de menubalk", isOn: $showMenuBarIcon)
                Toggle("Op alle schermen tonen", isOn: $showOnAllDisplays)
            } footer: {
                Text("Zonder menubalk-icoon open je deze instellingen via rechtsklik op het eiland.")
            }
            Section("Gedrag") {
                LabeledContent("Uitklappen na") {
                    Slider(value: $hoverDelay, in: 0...0.6, step: 0.05) {
                        EmptyView()
                    } minimumValueLabel: { Text("0 s") } maximumValueLabel: { Text("0,6 s") }
                }
                Toggle("Haptische feedback (trackpad)", isOn: $haptics)
            }
            Section("Toestemmingen") {
                permissionRow("Automatisering", detail: "Om Spotify en Muziek te bedienen", pane: "Privacy_Automation")
                permissionRow("Locatie", detail: "Voor het weer (globaal)", pane: "Privacy_LocationServices")
                permissionRow("Bluetooth", detail: "Voor AirPods-meldingen", pane: "Privacy_Bluetooth")
            }
            Section {
                HStack {
                    Text("Island 1.0")
                    Spacer()
                    Button("Stop Island") { NSApp.terminate(nil) }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var media: some View {
        Form {
            Section("Muziek") {
                Toggle("Hoes en golfvorm naast de notch tijdens afspelen", isOn: $compactMusic)
                Toggle("Songteksten tonen (via LRCLib)", isOn: $lyricsEnabled)
                    .onChange(of: lyricsEnabled) { _, _ in state.lyrics.load(state.nowPlaying.track) }
            }
            Section {
                Text("Island werkt met Spotify en Apple Music. Bij de eerste bediening vraagt macOS om toestemming voor automatisering.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var widgets: some View {
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
                }
            }
        }
        .formStyle(.grouped)
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
        Island 1.0 — macOS \(os)
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
