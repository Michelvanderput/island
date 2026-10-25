import AppKit

/// Zet vensters in een eigen 'space' met een absoluut niveau boven het vergrendelscherm.
/// Dit gebruikt niet-publieke functies uit SkyLight (dezelfde techniek als andere notch-apps);
/// alles wordt dynamisch geladen, dus als Apple iets verandert gebeurt er simpelweg niets.
final class SkyLight {
    static let shared = SkyLight()

    private typealias MainConnectionID = @convention(c) () -> Int32
    private typealias SpaceCreate = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias SpaceSetAbsoluteLevel = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias ShowSpaces = @convention(c) (Int32, CFArray) -> Int32
    private typealias SpaceAddWindows = @convention(c) (Int32, Int32, CFArray, Int32) -> Int32

    private let connection: Int32
    private let space: Int32
    private let addWindows: SpaceAddWindows?

    var isAvailable: Bool { addWindows != nil && space != 0 }

    private init() {
        let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight", RTLD_NOW)
        func load<T>(_ name: String, as type: T.Type) -> T? {
            guard let handle, let sym = dlsym(handle, name) else { return nil }
            return unsafeBitCast(sym, to: type)
        }
        guard let mainConnection = load("SLSMainConnectionID", as: MainConnectionID.self),
              let create = load("SLSSpaceCreate", as: SpaceCreate.self),
              let setLevel = load("SLSSpaceSetAbsoluteLevel", as: SpaceSetAbsoluteLevel.self),
              let show = load("SLSShowSpaces", as: ShowSpaces.self),
              let add = load("SLSSpaceAddWindowsAndRemoveFromSpaces", as: SpaceAddWindows.self) else {
            connection = 0
            space = 0
            addWindows = nil
            return
        }
        connection = mainConnection()
        space = create(connection, 1, 0)
        _ = setLevel(connection, space, 400)
        _ = show(connection, [space] as CFArray)
        addWindows = add
    }

    @discardableResult
    func delegate(_ window: NSWindow) -> Bool {
        guard isAvailable, let addWindows else { return false }
        return addWindows(connection, space, [window.windowNumber] as CFArray, 7) == 0
    }
}
