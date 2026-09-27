import Foundation
public struct NotchNotification: Identifiable, Equatable {
    public enum Kind: String { case music, calendar, files, memo, timer }
    public let id: UUID
    public let kind: Kind
    public let title: String
    public let subtitle: String
    public let icon: String
    public let duration: Double
    public let priority: Int
    public init(kind: Kind, title: String, subtitle: String, icon: String, duration: Double = 3, priority: Int = 0) {
        id = UUID(); self.kind = kind; self.title = title; self.subtitle = subtitle; self.icon = icon; self.duration = duration; self.priority = priority
    }
}
public struct NotificationQueue {
    public private(set) var pending: [NotchNotification] = []
    public init() {}
    public mutating func enqueue(_ item: NotchNotification) {
        // Coalesce repeated low-priority status updates; keep individual calendar events.
        if item.kind != .calendar { pending.removeAll { $0.kind == item.kind } }
        pending.append(item)
        if pending.count > 20 { pending.removeFirst() }
    }
    public mutating func dequeue() -> NotchNotification? {
        guard let index = pending.indices.max(by: { a, b in pending[a].priority == pending[b].priority ? a > b : pending[a].priority < pending[b].priority }) else { return nil }
        return pending.remove(at: index)
    }
}
