import Foundation
import Combine
#if SWIFT_PACKAGE
import NotchFlowCore
#endif
@MainActor final class MemoViewModel: ObservableObject {
    @Published private(set) var memos: [Memo] = []
    @Published var selectedID: UUID?
    @Published var error: String?
    @Published private(set) var writable = true
    @Published private(set) var saved = true
    var onSaved: (() -> Void)?
    private let store: LocalStore<[Memo]>
    private var saveTask: Task<Void, Never>?
    init(url: URL = StorageLocation.file("memos-v1.json")) {
        store = LocalStore(url: url)
        do { memos = try store.load(default: []); selectedID = Memo.recent(memos).first?.id }
        catch { writable = false; self.error = "메모 저장 파일을 읽을 수 없습니다. 원본을 보존했으므로 백업에서 복구할 수 있습니다."; AppLog.storage.error("Memo load failed") }
    }
    var selected: Memo? { memos.first { $0.id == selectedID } }
    var recent: [Memo] { Memo.recent(memos) }
    func create() { guard writable else { return }; let memo = Memo(); memos.insert(memo, at: 0); selectedID = memo.id; scheduleSave() }
    func update(_ edit: (inout Memo) -> Void) {
        guard writable, let index = memos.firstIndex(where: { $0.id == selectedID }) else { return }
        edit(&memos[index]); memos[index].updatedAt = Date(); scheduleSave()
    }
    func delete(_ id: UUID) { guard writable else { return }; memos.removeAll { $0.id == id }; if selectedID == id { selectedID = recent.first?.id }; scheduleSave() }
    private func scheduleSave() {
        saved = false; saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }
    func flush() {
        saveTask?.cancel()
        guard writable, !saved else { return }
        do { try store.save(memos); saved = true; error = nil; onSaved?() }
        catch { self.error = "메모를 저장하지 못했습니다. 저장 공간을 확인하고 다시 시도하세요."; AppLog.storage.error("Memo save failed") }
    }
}
