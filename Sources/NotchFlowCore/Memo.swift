import Foundation
public struct ChecklistItem: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var text: String
    public var done = false
    public init(text: String) { self.text = text }
}
public struct Memo: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var text: String
    public var pinned = false
    public var checklist: [ChecklistItem] = []
    public var updatedAt = Date()
    public init(text: String = "") { self.text = text }
    public var title: String { text.split(separator: "\n").first.map(String.init) ?? "새 메모" }
    public static func recent(_ memos: [Memo]) -> [Memo] { memos.sorted { $0.pinned != $1.pinned ? $0.pinned : $0.updatedAt > $1.updatedAt } }
}
