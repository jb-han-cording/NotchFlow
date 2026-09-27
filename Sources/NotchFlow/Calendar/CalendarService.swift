import EventKit
#if SWIFT_PACKAGE
import NotchFlowCore
#endif
@MainActor protocol CalendarProviding {
    var authorization: EKAuthorizationStatus { get }
    func requestAccess() async throws -> Bool
    func events(from: Date, to: Date) -> [CalendarEvent]
}
@MainActor final class CalendarService: CalendarProviding {
    private let store = EKEventStore()
    var authorization: EKAuthorizationStatus { EKEventStore.authorizationStatus(for: .event) }
    func requestAccess() async throws -> Bool { try await store.requestFullAccessToEvents() }
    func events(from: Date, to: Date) -> [CalendarEvent] {
        guard authorization == .fullAccess else { return [] }
        return store.events(matching: store.predicateForEvents(withStart: from, end: to, calendars: nil)).map {
            CalendarEvent(id: ($0.eventIdentifier ?? "event") + String($0.startDate.timeIntervalSince1970), title: $0.title ?? "제목 없는 일정", start: $0.startDate, end: $0.endDate, isAllDay: $0.isAllDay)
        }
    }
}
