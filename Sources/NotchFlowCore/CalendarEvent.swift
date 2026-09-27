import Foundation
public struct CalendarEvent: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public init(id: String, title: String, start: Date, end: Date, isAllDay: Bool = false) { self.id = id; self.title = title; self.start = start; self.end = end; self.isAllDay = isAllDay }
    public static func upcoming(_ events: [CalendarEvent], at now: Date) -> [CalendarEvent] {
        events.filter { $0.end > now }.sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
    }
}
