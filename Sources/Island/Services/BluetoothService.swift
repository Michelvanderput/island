import Foundation
import IOBluetooth

struct BluetoothBattery: Equatable {
    var single: Int?
    var left: Int?
    var right: Int?
    var caseLevel: Int?

    var isEmpty: Bool { single == nil && left == nil && right == nil && caseLevel == nil }
    /// Laagste oorbatterij, of de enkele waarde (koptelefoon).
    var headline: Int? {
        if let single { return single }
        let buds = [left, right].compactMap { $0 }
        return buds.min()
    }
}

struct BluetoothDeviceInfo: Equatable, Identifiable {
    var id: String
    var name: String
    var battery: BluetoothBattery

    var symbol: String {
        let n = name.lowercased()
        if n.contains("airpods max") { return "airpodsmax" }
        if n.contains("airpods pro") { return "airpodspro" }
        if n.contains("airpods") { return "airpods" }
        if n.contains("beats") { return "beats.headphones" }
        return "headphones"
    }
}

/// Meldt verbinding/ontkoppeling van Bluetooth-audio (AirPods, koptelefoons).
final class BluetoothService: NSObject, ObservableObject {
    @Published private(set) var connected: [BluetoothDeviceInfo] = []

    var onEvent: ((HUD) -> Void)?

    private var connectNotification: IOBluetoothUserNotification?
    private var launchDate = Date()

    func start() {
        launchDate = Date()
        connectNotification = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(deviceConnected(_:device:)))
    }

    @objc private func deviceConnected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        // Alleen audio (major class 0x04).
        guard device.deviceClassMajor == 0x04 else { return }
        device.register(forDisconnectNotification: self, selector: #selector(deviceDisconnected(_:device:)))

        let silent = Date().timeIntervalSince(launchDate) < 3
        var info = Self.info(for: device)
        upsert(info)
        if !silent, Pref.bool(Pref.bluetoothAlerts) {
            onEvent?(.bluetooth(info, connected: true))
        }
        // De batterij is vlak na verbinden vaak nog niet bekend.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self, device.isConnected() else { return }
            info = Self.info(for: device)
            self.upsert(info)
            if !silent, Pref.bool(Pref.bluetoothAlerts), !info.battery.isEmpty {
                self.onEvent?(.bluetooth(info, connected: true))
            }
        }
    }

    @objc private func deviceDisconnected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        note.unregister()
        let info = Self.info(for: device)
        connected.removeAll { $0.id == info.id }
        if Pref.bool(Pref.bluetoothAlerts) {
            onEvent?(.bluetooth(info, connected: false))
        }
    }

    private func upsert(_ info: BluetoothDeviceInfo) {
        if let i = connected.firstIndex(where: { $0.id == info.id }) {
            connected[i] = info
        } else {
            connected.append(info)
        }
    }

    private static func info(for device: IOBluetoothDevice) -> BluetoothDeviceInfo {
        BluetoothDeviceInfo(
            id: device.addressString ?? UUID().uuidString,
            name: device.name ?? "Bluetooth-apparaat",
            battery: BluetoothBattery(
                single: percent(device, "batteryPercentSingle"),
                left: percent(device, "batteryPercentLeft"),
                right: percent(device, "batteryPercentRight"),
                caseLevel: percent(device, "batteryPercentCase")))
    }

    /// IOBluetoothDevice heeft (niet-publieke) batterij-eigenschappen voor Apple-audio.
    /// We vragen ze alleen op als het object erop reageert, zodat er nooit iets crasht.
    private static func percent(_ device: IOBluetoothDevice, _ key: String) -> Int? {
        guard device.responds(to: Selector(key)),
              let value = (device.value(forKey: key) as? NSNumber)?.intValue,
              value > 0, value <= 100 else { return nil }
        return value
    }
}
