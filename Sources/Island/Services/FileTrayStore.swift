import AppKit

struct TrayItem: Identifiable, Equatable {
    let url: URL
    var id: String { url.path }
    var name: String { url.lastPathComponent }
    var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }
}

/// De bestandenlade: sleep bestanden op de notch om ze even te parkeren, sleep ze er later weer uit.
final class FileTrayStore: ObservableObject {
    @Published private(set) var items: [TrayItem] = []

    private let key = "trayPaths"

    init() {
        let paths = UserDefaults.standard.stringArray(forKey: key) ?? []
        items = paths.map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .map(TrayItem.init)
    }

    func add(_ urls: [URL]) {
        for url in urls where !items.contains(where: { $0.url == url }) {
            items.append(TrayItem(url: url))
        }
        save()
    }

    func remove(_ item: TrayItem) {
        items.removeAll { $0 == item }
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    func open(_ item: TrayItem) { NSWorkspace.shared.open(item.url) }
    func reveal(_ item: TrayItem) { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }

    func airDrop(_ items: [TrayItem]) {
        NSSharingService(named: .sendViaAirDrop)?.perform(withItems: items.map(\.url))
    }

    private func save() {
        UserDefaults.standard.set(items.map(\.url.path), forKey: key)
    }
}
