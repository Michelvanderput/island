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

    /// Map voor kopieën als 'Kopieer bestanden naar de lade' aan staat.
    static let folder: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Island/Lade", isDirectory: true)
    }()

    func add(_ urls: [URL]) {
        for url in urls where !items.contains(where: { $0.url == url }) {
            let stored = Pref.bool(Pref.trayCopyFiles) ? copyIntoTray(url) ?? url : url
            items.append(TrayItem(url: stored))
        }
        save()
    }

    func remove(_ item: TrayItem) {
        items.removeAll { $0 == item }
        deleteCopy(item)
        save()
    }

    func clear() {
        items.forEach(deleteCopy)
        items.removeAll()
        save()
    }

    private func copyIntoTray(_ url: URL) -> URL? {
        let fm = FileManager.default
        try? fm.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        var target = Self.folder.appendingPathComponent(url.lastPathComponent)
        var n = 2
        while fm.fileExists(atPath: target.path) {
            let ext = url.pathExtension
            let stem = url.deletingPathExtension().lastPathComponent
            target = Self.folder.appendingPathComponent(ext.isEmpty ? "\(stem) \(n)" : "\(stem) \(n).\(ext)")
            n += 1
        }
        do {
            try fm.copyItem(at: url, to: target)
            return target
        } catch {
            NSLog("Island lade: kopiëren mislukt: \(error)")
            return nil
        }
    }

    /// Alleen eigen kopieën worden weggegooid, nooit je originele bestanden.
    private func deleteCopy(_ item: TrayItem) {
        guard item.url.path.hasPrefix(Self.folder.path) else { return }
        try? FileManager.default.removeItem(at: item.url)
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
