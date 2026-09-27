import XCTest
import CoreGraphics
@testable import NotchFlowCore

final class GeometryTests: XCTestCase {
    func testCollapsedFrameMatchesNotchHeightWithAndWithoutMusic() {
        let screen = CGRect(x: -1512, y: 120, width: 1512, height: 982)
        let geometry = NotchGeometry(screen: screen, topInset: 38,
            leftArea: CGRect(x: -1512, y: 1064, width: 646, height: 38),
            rightArea: CGRect(x: -646, y: 1064, width: 646, height: 38))
        for playing in [false, true] {
            let closed = geometry.collapsedFrame(musicPlaying: playing)
            XCTAssertEqual(closed.height, geometry.cutout.height)
            XCTAssertEqual(closed.minY, geometry.cutout.minY)
            XCTAssertEqual(closed.maxY, screen.maxY)
            XCTAssertEqual(closed.midX, geometry.cutout.midX)
        }
    }
    func testActualNotchUsesAuxiliaryGap() {
        let value = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1512, height: 982), topInset: 32, leftArea: CGRect(x: 0, y: 950, width: 660, height: 32), rightArea: CGRect(x: 852, y: 950, width: 660, height: 32))
        XCTAssertTrue(value.hasNotch)
        XCTAssertEqual(value.cutout, CGRect(x: 660, y: 950, width: 192, height: 32))
        XCTAssertEqual(value.frame(width: 460, height: 600).maxY, 982)
    }
    func testExternalMonitorNegativeOrigin() {
        let value = NotchGeometry(screen: CGRect(x: -1920, y: 150, width: 1920, height: 1080), topInset: 0, leftArea: nil, rightArea: nil)
        XCTAssertFalse(value.hasNotch)
        XCTAssertEqual(value.frame(width: 460, height: 600).midX, -960)
        XCTAssertEqual(value.frame(width: 460, height: 600).maxY, 1230)
    }
    func testFrameClampsToSmallScreen() {
        let value = NotchGeometry(screen: CGRect(x: 100, y: -500, width: 400, height: 300), topInset: 0, leftArea: nil, rightArea: nil)
        let frame = value.frame(width: 900, height: 800)
        XCTAssertLessThanOrEqual(frame.maxX, value.screen.maxX)
        XCTAssertGreaterThanOrEqual(frame.minY, value.screen.minY)
    }
    func testMissingAuxiliaryDataFallsBack() {
        XCTAssertFalse(NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1400, height: 900), topInset: 32, leftArea: nil, rightArea: nil).hasNotch)
    }
    func testPathologicalDisplayInsetsCannotCreateFullScreenCollapsedNotch() {
        let value = NotchGeometry(
            screen: CGRect(x: 0, y: 0, width: 1440, height: 900),
            topInset: 0,
            leftArea: nil,
            rightArea: nil,
            menuBarHeight: 900
        )
        XCTAssertEqual(value.cutout.height, 96)
        XCTAssertLessThan(value.collapsedFrame(musicPlaying: false).height, 100)
    }
}
final class StateTests: XCTestCase {
    func testHoverOpenOutsideClick() { var state = NotchStateMachine(); state.send(.hover); XCTAssertEqual(state.state, .hover); state.send(.open); state.send(.exitHover); XCTAssertEqual(state.state, .expanded); state.send(.close); XCTAssertEqual(state.state, .collapsed) }
    func testDraggingRestoresExpandedState() { var state = NotchStateMachine(); state.send(.open); state.send(.dragEnter); state.send(.dragEnter); state.send(.dragExit); XCTAssertEqual(state.state, .expanded) }
    func testDropExpands() { var state = NotchStateMachine(); state.send(.dragEnter); state.send(.drop); state.send(.dragExit); XCTAssertEqual(state.state, .expanded) }
    func testNotificationRestoresCollapsedState() { var state = NotchStateMachine(); state.send(.notify); XCTAssertEqual(state.state, .notification); state.send(.endNotification); XCTAssertEqual(state.state, .collapsed) }
    func testNotificationDoesNotInterruptTyping() { var state = NotchStateMachine(); state.send(.open); state.send(.notify); state.send(.endNotification); XCTAssertEqual(state.state, .expanded) }
    func testClickDuringNotificationKeepsExpanded() { var state = NotchStateMachine(); state.send(.notify); state.send(.open); state.send(.endNotification); XCTAssertEqual(state.state, .expanded) }
    func testNotificationDoesNotInterruptDrop() { var state = NotchStateMachine(); state.send(.dragEnter); state.send(.notify); state.send(.endNotification); XCTAssertEqual(state.state, .dragActive) }
}
final class PersistenceTests: XCTestCase {
    func testLegacySettingsKeepValuesAndDefaultOnlyMissingKeys() throws {
        let legacy = Data(#"{"openOnHover":false,"hoverDelay":0.8,"theme":"Light","expandedWidth":460,"musicEnabled":false,"musicNotifications":false,"shortcut":"Disabled"}"#.utf8)
        var settings = try JSONDecoder().decode(AppSettings.self, from: legacy)
        settings.normalize()
        XCTAssertFalse(settings.openOnHover)
        XCTAssertFalse(settings.musicEnabled)
        XCTAssertEqual(settings.hoverDelay, 0.8)
        XCTAssertEqual(settings.theme, "Light")
        XCTAssertEqual(settings.expandedWidth, 460)
        XCTAssertEqual(settings.shortcut, "Disabled")
        XCTAssertEqual(settings.memoNotifications, AppSettings().memoNotifications)
        XCTAssertEqual(settings.cornerRadius, AppSettings().cornerRadius)
        XCTAssertFalse(settings.expandOnTrackChange)
        XCTAssertFalse(settings.hasCompletedOnboarding)
        XCTAssertTrue(settings.automaticUpdateChecks)
        XCTAssertTrue(settings.showMenuBarIcon)
    }
    func testNewerUnknownSettingDoesNotDiscardKnownPreferences() throws {
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"blur":false,"theme":"Dark","futureOption":{"enabled":true}}"#.utf8))
        XCTAssertFalse(settings.blur)
        XCTAssertEqual(settings.theme, "Dark")
    }
    func testMalformedSettingIsNotSilentlyTreatedAsMissing() {
        XCTAssertThrowsError(try JSONDecoder().decode(AppSettings.self, from: Data(#"{"openOnHover":"invalid"}"#.utf8)))
    }
    private func temporary() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("data.json") }
    func testMemoRoundTrip() throws {
        let url = temporary(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = LocalStore<[Memo]>(url: url)
        var memo = Memo(text: "오늘 서버 점검\n두 번째 줄"); memo.pinned = true; memo.checklist = [ChecklistItem(text: "테스트 완료")]; memo.checklist[0].done = true
        try store.save([memo]); XCTAssertEqual(try store.load(default: []), [memo])
    }
    func testMissingStoreReturnsDefault() throws { XCTAssertEqual(try LocalStore<[Memo]>(url: temporary()).load(default: []), []) }
    func testCorruptedDataIsNotOverwrittenByLoad() throws {
        let url = temporary(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let bad = Data("invalid json".utf8); try bad.write(to: url)
        XCTAssertThrowsError(try LocalStore<[Memo]>(url: url).load(default: [])); XCTAssertEqual(try Data(contentsOf: url), bad)
    }
    func testPinnedMemoSortsFirst() { var old = Memo(text: "old"); old.pinned = true; old.updatedAt = .distantPast; XCTAssertEqual(Memo.recent([Memo(text: "new"), old]).first?.id, old.id) }
    func testSettingsRoundTripAndNormalization() throws {
        let url = temporary(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var settings = AppSettings(); settings.expandedWidth = 99999; settings.hoverDelay = -1; settings.theme = "Unknown"; settings.normalize()
        XCTAssertEqual(settings.expandedWidth, 900); XCTAssertEqual(settings.hoverDelay, 0.05); XCTAssertEqual(settings.theme, "System")
        let store = LocalStore<AppSettings>(url: url); try store.save(settings); XCTAssertEqual(try store.load(default: AppSettings()), settings)
    }
    func testShelfBookmarkRoundTrip() throws {
        let item = ShelfItem(bookmark: Data([0, 1, 2]), originalPath: "/tmp/report.pdf", name: "report.pdf")
        let loaded = try JSONDecoder().decode(ShelfItem.self, from: JSONEncoder().encode(item))
        XCTAssertEqual(loaded.id, item.id); XCTAssertEqual(loaded.bookmark, item.bookmark); XCTAssertEqual(loaded.originalPath, item.originalPath)
    }
}
final class CalendarAndQueueTests: XCTestCase {
    func testUpcomingFiltersEndedEventsAndSorts() {
        let now = Date()
        let ended = CalendarEvent(id: "a", title: "ended", start: now.addingTimeInterval(-200), end: now.addingTimeInterval(-1))
        let later = CalendarEvent(id: "b", title: "later", start: now.addingTimeInterval(100), end: now.addingTimeInterval(200))
        let active = CalendarEvent(id: "c", title: "active", start: now.addingTimeInterval(-20), end: now.addingTimeInterval(20))
        XCTAssertEqual(CalendarEvent.upcoming([later, ended, active], at: now).map(\.id), ["c", "b"])
    }
    func testPriorityAndFIFO() {
        var queue = NotificationQueue()
        let a = NotchNotification(kind: .calendar, title: "a", subtitle: "", icon: "", priority: 2)
        let b = NotchNotification(kind: .calendar, title: "b", subtitle: "", icon: "", priority: 10)
        let c = NotchNotification(kind: .calendar, title: "c", subtitle: "", icon: "", priority: 2)
        [a,b,c].forEach { queue.enqueue($0) }
        XCTAssertEqual(queue.dequeue()?.id, b.id); XCTAssertEqual(queue.dequeue()?.id, a.id); XCTAssertEqual(queue.dequeue()?.id, c.id); XCTAssertNil(queue.dequeue())
    }
    func testCoalescesRepeatedMusicChanges() {
        var queue = NotificationQueue()
        queue.enqueue(NotchNotification(kind: .music, title: "old", subtitle: "", icon: "")); queue.enqueue(NotchNotification(kind: .music, title: "new", subtitle: "", icon: ""))
        XCTAssertEqual(queue.pending.count, 1); XCTAssertEqual(queue.dequeue()?.title, "new")
    }
    func testQueueIsBounded() {
        var queue = NotificationQueue()
        for _ in 0..<100 { queue.enqueue(NotchNotification(kind: .calendar, title: "", subtitle: "", icon: "")) }
        XCTAssertEqual(queue.pending.count, 20)
    }
}
