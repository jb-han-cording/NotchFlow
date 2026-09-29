import Foundation
public struct CalendarEvent: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public var meetingURL: URL?
    public init(id: String, title: String, start: Date, end: Date, isAllDay: Bool = false, meetingURL: URL? = nil) { self.id = id; self.title = title; self.start = start; self.end = end; self.isAllDay = isAllDay; self.meetingURL = meetingURL }
    public static func meetingLink(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        return detector.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap(\.url).first { url in
            guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else { return false }
            return ["zoom.us", "zoom.com", "meet.google.com", "teams.microsoft.com", "teams.live.com", "teams.cloud.microsoft"].contains { host == $0 || host.hasSuffix("." + $0) }
        }
    }
    public static func upcoming(_ events: [CalendarEvent], at now: Date) -> [CalendarEvent] {
        events.filter { $0.end > now }.sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
    }
}
