import XCTest
@testable import NotchFlow

@MainActor final class FocusTimerTests: XCTestCase {
    func testPauseResumePreservesRemainingTime() {
        let timer = FocusTimer()
        let start = Date(timeIntervalSince1970: 1000)
        timer.configure(minutes: 5)
        timer.start(now: start, schedule: false)
        timer.pause(now: start.addingTimeInterval(70))
        XCTAssertEqual(timer.remaining, 230)
        XCTAssertTrue(timer.active)
        XCTAssertFalse(timer.running)
        timer.start(now: start.addingTimeInterval(200), schedule: false)
        timer.tick(now: start.addingTimeInterval(210))
        XCTAssertEqual(timer.remaining, 220)
        timer.reset()
        XCTAssertEqual(timer.remaining, 300)
        XCTAssertFalse(timer.active)
    }

    func testDelayedTickCompletesExactlyOnce() {
        let timer = FocusTimer()
        var completions = 0
        timer.onComplete = { completions += 1 }
        let start = Date(timeIntervalSince1970: 1000)
        timer.configure(minutes: 1)
        timer.start(now: start, schedule: false)
        timer.tick(now: start.addingTimeInterval(300))
        timer.tick(now: start.addingTimeInterval(301))
        XCTAssertEqual(completions, 1)
        XCTAssertEqual(timer.remaining, 0)
        XCTAssertFalse(timer.active)
        timer.start(now: start.addingTimeInterval(302), schedule: false)
        XCTAssertEqual(timer.remaining, 60)
    }
}
