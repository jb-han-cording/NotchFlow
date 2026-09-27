import AppKit
import Combine
#if SWIFT_PACKAGE
import NotchFlowCore
#endif
@MainActor final class FileShelfViewModel: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []
    @Published private(set) var urls: [UUID: URL] = [:]
    @Published var error: String?
    @Published private(set) var writable = true
    var onAdded: ((Int) -> Void)?
    private let service: FileShelfProviding
    private let store: LocalStore<[ShelfItem]>
    private var scoped: [URL] = []
    init(service: FileShelfProviding = FileShelfService(), url: URL = StorageLocation.file("shelf-v1.json")) {
        self.service = service; store = LocalStore(url: url)
        do { items = try store.load(default: []); refresh() }
        catch { writable = false; self.error = "파일 선반 저장 데이터를 읽을 수 없습니다. 원본 저장 파일을 보존했습니다."; AppLog.storage.error("Shelf load failed") }
    }
    func refresh() {
        scoped.forEach { $0.stopAccessingSecurityScopedResource() }; scoped.removeAll(); urls.removeAll()
        for index in items.indices {
            do {
                let resolved = try service.resolve(items[index])
                if resolved.url.startAccessingSecurityScopedResource() { scoped.append(resolved.url) }
                guard FileManager.default.fileExists(atPath: resolved.url.path) else { AppLog.storage.info("File Missing"); continue }
                urls[items[index].id] = resolved.url
                if resolved.stale { items[index].bookmark = try service.bookmark(for: resolved.url) }
            } catch { AppLog.storage.error("Bookmark resolution failed") }
        }
        persist()
    }
    func add(_ incoming: [URL]) {
        guard writable else { return }
        var count = 0
        var known = Set(urls.values.map { $0.standardizedFileURL })
        for url in incoming where url.isFileURL {
            guard !known.contains(url.standardizedFileURL) else { continue }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let item = ShelfItem(bookmark: try service.bookmark(for: url), originalPath: url.path, name: url.lastPathComponent)
                items.append(item); known.insert(url.standardizedFileURL); count += 1
            } catch { self.error = "일부 파일에 접근할 수 없습니다. Finder에서 다시 추가하세요." }
        }
        refresh()
        if count > 0 { AppLog.storage.info("File Added: \(count)"); onAdded?(count) }
    }
    func remove(_ item: ShelfItem) { guard writable else { return }; items.removeAll { $0.id == item.id }; refresh() }
    func clear() { guard writable else { return }; items.removeAll(); refresh() }
    private func persist() {
        guard writable else { return }
        do { try store.save(items) } catch { self.error = "파일 선반을 저장하지 못했습니다."; AppLog.storage.error("Shelf save failed") }
    }
    func stop() { scoped.forEach { $0.stopAccessingSecurityScopedResource() }; scoped.removeAll() }
}
