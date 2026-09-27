import Foundation
public struct ShelfItem: Codable, Identifiable {
    public let id: UUID
    public var bookmark: Data
    public let originalPath: String
    public let name: String
    public let addedAt: Date
    public init(id: UUID = UUID(), bookmark: Data, originalPath: String, name: String, addedAt: Date = Date()) {
        self.id = id; self.bookmark = bookmark; self.originalPath = originalPath; self.name = name; self.addedAt = addedAt
    }
}
