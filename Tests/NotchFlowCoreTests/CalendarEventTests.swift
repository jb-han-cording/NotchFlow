import XCTest
@testable import NotchFlowCore

final class CalendarEventTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return value
    }
    private func date(_ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour))!
    }
    private func event(_ start: Date, _ end: Date) -> CalendarEvent {
        CalendarEvent(id: "test", title: "Test", start: start, end: end)
    }
    func testMidnightEndDoesNotMarkFollowingDay() {
        let value = event(date(7, hour: 23), date(8))
        XCTAssertTrue(value.occurs(on: date(7), calendar: calendar))
        XCTAssertFalse(value.occurs(on: date(8), calendar: calendar))
    }
    func testMultiDayEventMarksEveryOverlappingDay() {
        let value = event(date(7, hour: 12), date(10, hour: 12))
        for day in 7...10 { XCTAssertTrue(value.occurs(on: date(day), calendar: calendar)) }
        XCTAssertFalse(value.occurs(on: date(6), calendar: calendar))
        XCTAssertFalse(value.occurs(on: date(11), calendar: calendar))
    }
    func testZeroDurationEventBelongsToItsStartDay() {
        let value = event(date(8), date(8))
        XCTAssertTrue(value.occurs(on: date(8), calendar: calendar))
        XCTAssertFalse(value.occurs(on: date(7), calendar: calendar))
    }
    func testDayAfterDSTDoesNotLeakIntoPreviousDay() {
        // March 8 has 23 hours in Los Angeles; adding 86400 would be wrong.
        let value = event(date(9), date(9, hour: 1))
        XCTAssertFalse(value.occurs(on: date(8), calendar: calendar))
        XCTAssertTrue(value.occurs(on: date(9), calendar: calendar))
    }
}
