import Foundation
import CoreAudio
import AudioToolbox

struct AudioDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
    let transport: UInt32

    var symbol: String {
        let n = name.lowercased()
        if n.contains("airpods max") { return "airpodsmax" }
        if n.contains("airpods pro") { return "airpodspro" }
        if n.contains("airpods") { return "airpods" }
        switch transport {
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return "headphones"
        case kAudioDeviceTransportTypeAirPlay: return "airplayaudio"
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort: return "tv"
        case kAudioDeviceTransportTypeUSB: return "hifispeaker"
        case kAudioDeviceTransportTypeBuiltIn: return "laptopcomputer"
        default: return "speaker.wave.2"
        }
    }
}

/// Audio-uitgangen en volume via CoreAudio, met property listeners (geen polling).
final class AudioOutputService: ObservableObject {
    @Published private(set) var devices: [AudioDevice] = []
    @Published private(set) var currentID: AudioDeviceID = 0
    @Published private(set) var volume: Float = 0.5

    private var volumeListenerDevice: AudioDeviceID = 0
    private lazy var volumeListener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        self?.readVolume()
    }

    var current: AudioDevice? { devices.first { $0.id == currentID } }

    func start() {
        var devicesAddress = Self.address(kAudioHardwarePropertyDevices)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devicesAddress, .main) { [weak self] _, _ in
            self?.reload()
        }
        var defaultAddress = Self.address(kAudioHardwarePropertyDefaultOutputDevice)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultAddress, .main) { [weak self] _, _ in
            self?.reload()
        }
        reload()
    }

    func select(_ device: AudioDevice) {
        var id = device.id
        var address = Self.address(kAudioHardwarePropertyDefaultOutputDevice)
        AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil,
                                   UInt32(MemoryLayout<AudioDeviceID>.size), &id)
        // Ook systeemgeluiden meeverhuizen.
        var systemAddress = Self.address(kAudioHardwarePropertyDefaultSystemOutputDevice)
        AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &systemAddress, 0, nil,
                                   UInt32(MemoryLayout<AudioDeviceID>.size), &id)
    }

    func setVolume(_ value: Float) {
        volume = value
        var v = Float32(max(0, min(1, value)))
        var address = Self.address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioDevicePropertyScopeOutput)
        AudioObjectSetPropertyData(currentID, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
    }

    // MARK: Intern

    private func reload() {
        var defaultID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var defaultAddress = Self.address(kAudioHardwarePropertyDefaultOutputDevice)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultAddress, 0, nil, &size, &defaultID)

        var listAddress = Self.address(kAudioHardwarePropertyDevices)
        var listSize: UInt32 = 0
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &listAddress, 0, nil, &listSize)
        var ids = [AudioDeviceID](repeating: 0, count: Int(listSize) / MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &listAddress, 0, nil, &listSize, &ids)

        devices = ids.filter(Self.hasOutput).compactMap { id in
            guard let name = Self.name(of: id) else { return nil }
            return AudioDevice(id: id, name: name, transport: Self.transport(of: id))
        }
        .filter { $0.transport != kAudioDeviceTransportTypeAggregate && $0.transport != kAudioDeviceTransportTypeVirtual || $0.id == defaultID }
        currentID = defaultID
        listenToVolume(of: defaultID)
        readVolume()
    }

    private func listenToVolume(of device: AudioDeviceID) {
        guard device != volumeListenerDevice else { return }
        var address = Self.address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioDevicePropertyScopeOutput)
        if volumeListenerDevice != 0 {
            AudioObjectRemovePropertyListenerBlock(volumeListenerDevice, &address, .main, volumeListener)
        }
        AudioObjectAddPropertyListenerBlock(device, &address, .main, volumeListener)
        volumeListenerDevice = device
    }

    private func readVolume() {
        var v = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = Self.address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioDevicePropertyScopeOutput)
        if AudioObjectGetPropertyData(currentID, &address, 0, nil, &size, &v) == noErr {
            volume = v
        }
    }

    private static func address(_ selector: AudioObjectPropertySelector,
                                scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func hasOutput(_ id: AudioDeviceID) -> Bool {
        var addr = address(kAudioDevicePropertyStreams, scope: kAudioDevicePropertyScopeOutput)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr && size > 0
    }

    private static func name(of id: AudioDeviceID) -> String? {
        var addr = address(kAudioObjectPropertyName)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &name) == noErr else { return nil }
        return name?.takeRetainedValue() as String?
    }

    private static func transport(of id: AudioDeviceID) -> UInt32 {
        var addr = address(kAudioDevicePropertyTransportType)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value)
        return value
    }
}
