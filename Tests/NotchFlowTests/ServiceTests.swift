import XCTest
import EventKit
import AppKit
import NotchFlowCore
@testable import NotchFlow

@MainActor final class DeniedCalendar: CalendarProviding {
    var authorization: EKAuthorizationStatus { .denied }
    func requestAccess() async throws -> Bool { false }
    func events(from: Date, to: Date) -> [CalendarEvent] { XCTFail("Must not read denied calendars"); return [] }
}
@MainActor final class PermissionCalendar: CalendarProviding {
    var authorization: EKAuthorizationStatus = .notDetermined
    var requestCount = 0
    var eventReadCount = 0
    var result = false
    var nextAuthorization: EKAuthorizationStatus = .notDetermined
    var requestError: Error?
    func requestAccess() async throws -> Bool {
        requestCount += 1
        if let requestError { throw requestError }
        authorization = nextAuthorization
        return result
    }
    func events(from: Date, to: Date) -> [CalendarEvent] {
        eventReadCount += 1
        XCTAssertEqual(authorization, .fullAccess)
        return []
    }
}
final class MockShelf: FileShelfProviding {
    func bookmark(for url: URL) throws -> Data { Data(url.path.utf8) }
    func resolve(_ item: ShelfItem) throws -> (url: URL, stale: Bool) { (URL(fileURLWithPath: item.originalPath), false) }
}
final class ServiceTests: XCTestCase {
    @MainActor func testDeniedCalendarDoesNotRepeatSystemRequest() async {
        let service = PermissionCalendar()
        service.authorization = .denied
        let model = CalendarViewModel(service: service)
        defer { model.stop() }
        await model.connect()
        XCTAssertEqual(service.requestCount, 0)
        XCTAssertEqual(service.eventReadCount, 0)
        XCTAssertEqual(model.authorization, .denied)
        XCTAssertTrue(model.status.contains("시스템 설정"))
    }
    @MainActor func testRestrictedCalendarExplainsPolicyWithoutRequesting() async {
        let service = PermissionCalendar()
        service.authorization = .restricted
        let model = CalendarViewModel(service: service)
        defer { model.stop() }
        await model.connect()
        XCTAssertEqual(service.requestCount, 0)
        XCTAssertTrue(model.status.contains("관리 정책"))
    }
    @MainActor func testCalendarGrantLoadsEventsAndClearsRequesting() async {
        let service = PermissionCalendar()
        service.result = true
        service.nextAuthorization = .fullAccess
        let model = CalendarViewModel(service: service)
        defer { model.stop() }
        await model.connect()
        XCTAssertEqual(service.requestCount, 1)
        XCTAssertEqual(service.eventReadCount, 1)
        XCTAssertTrue(model.authorized)
        XCTAssertFalse(model.requesting)
    }
    @MainActor func testCalendarRequestWithoutSystemPromptShowsRecoveryMessage() async {
        let service = PermissionCalendar()
        let model = CalendarViewModel(service: service)
        defer { model.stop() }
        await model.connect()
        XCTAssertFalse(model.requesting)
        XCTAssertFalse(model.authorized)
        XCTAssertTrue(model.status.contains("완료하지 못했습니다"))
    }
    @MainActor func testCalendarRequestErrorLeavesRetryAvailable() async {
        let service = PermissionCalendar()
        service.requestError = NSError(domain: "CalendarTest", code: 42)
        let model = CalendarViewModel(service: service)
        defer { model.stop() }
        await model.connect()
        XCTAssertFalse(model.requesting)
        XCTAssertTrue(model.status.contains("42"))
        service.requestError = nil
        service.result = true
        service.nextAuthorization = .fullAccess
        await model.connect()
        XCTAssertTrue(model.authorized)
        XCTAssertEqual(service.requestCount, 2)
    }
    @MainActor func testCalendarRefreshDetectsSettingsChangeAndRevocation() {
        let service = PermissionCalendar()
        service.authorization = .denied
        let model = CalendarViewModel(service: service)
        defer { model.stop() }
        service.authorization = .fullAccess
        model.refresh()
        XCTAssertTrue(model.authorized)
        service.authorization = .denied
        model.refresh()
        XCTAssertFalse(model.authorized)
        XCTAssertTrue(model.events.isEmpty)
        XCTAssertEqual(service.eventReadCount, 1)
    }
    @MainActor func testWriteOnlyCalendarCanRequestFullAccess() async {
        let service = PermissionCalendar()
        service.authorization = .writeOnly
        service.nextAuthorization = .fullAccess
        service.result = true
        let model = CalendarViewModel(service: service)
        defer { model.stop() }
        await model.connect()
        XCTAssertEqual(service.requestCount, 1)
        XCTAssertTrue(model.authorized)
    }
    @MainActor func testSettingsUpgradePreservesPreferencesAndOriginalBackup() throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("settings-v1.json")
        let legacy = Data(#"{"theme":"Light","openOnHover":false,"expandedWidth":460,"hoverDelay":0.9}"#.utf8)
        try legacy.write(to: url)
        let upgraded = SettingsViewModel(url: url, updateVersion: "2")
        XCTAssertEqual(upgraded.value.theme, "Light")
        XCTAssertEqual(upgraded.value.expandedWidth, 460)
        XCTAssertFalse(upgraded.value.openOnHover)
        XCTAssertNil(upgraded.error)
        XCTAssertEqual(try Data(contentsOf: url), legacy)
        upgraded.value.blur = false
        XCTAssertNil(upgraded.error)
        let backup = url.appendingPathExtension("before-2.bak")
        XCTAssertEqual(try Data(contentsOf: backup), legacy)
        let restarted = SettingsViewModel(url: url, updateVersion: "2")
        XCTAssertEqual(restarted.value, upgraded.value)
        restarted.value.theme = "Dark"
        XCTAssertEqual(try Data(contentsOf: backup), legacy)
        XCTAssertEqual(restarted.value.hoverDelay, 0.9)
    }
    @MainActor func testDamagedSettingsRemainUntouchedAfterUpdate() throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("settings-v1.json")
        let bad = Data(#"{"hoverDelay":"damaged"}"#.utf8)
        try bad.write(to: url)
        let model = SettingsViewModel(url: url, updateVersion: "2")
        XCTAssertNotNil(model.error)
        model.value.theme = "Light"
        XCTAssertEqual(try Data(contentsOf: url), bad)
    }
    @MainActor func testBriefPointerExitDoesNotCollapsePreview() async throws {
        let model = NotchViewModel()
        defer { model.stop() }
        model.hover(true, enabled: true, delay: 0)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(model.state, .hover)
        model.hover(false, enabled: true, delay: 0)
        XCTAssertEqual(model.state, .hover)
        model.hover(true, enabled: true, delay: 0)
        try await Task.sleep(for: .milliseconds(220))
        XCTAssertEqual(model.state, .hover)
        model.hover(false, enabled: true, delay: 0)
        try await Task.sleep(for: .milliseconds(220))
        XCTAssertEqual(model.state, .collapsed)
    }
    @MainActor func testRepeatedEntryDoesNotRestartHoverDelay() async throws {
        let model = NotchViewModel()
        defer { model.stop() }
        model.hover(true, enabled: true, delay: 0.06)
        model.hover(true, enabled: true, delay: 10)
        try await Task.sleep(for: .milliseconds(160))
        XCTAssertEqual(model.state, .hover)
    }
    @MainActor func testCloseCancelsPendingHoverEvenWhenAlreadyCollapsed() async throws {
        let model = NotchViewModel()
        defer { model.stop() }
        model.hover(true, enabled: true, delay: 0.05)
        model.send(.close)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(model.state, .collapsed)
    }
    @MainActor func testHoverExitDoesNotCloseExplicitlyOpenedPanel() async throws {
        let model = NotchViewModel()
        defer { model.stop() }
        model.hover(true, enabled: true, delay: 0)
        try await Task.sleep(for: .milliseconds(50))
        model.hover(false, enabled: true, delay: 0)
        model.send(.open)
        try await Task.sleep(for: .milliseconds(220))
        XCTAssertEqual(model.state, .expanded)
    }
    @MainActor func testHeaderClickPinsHoverPreviewAndThenClosesExpandedPanel() async throws {
        let model = NotchViewModel()
        defer { model.stop() }
        model.hover(true, enabled: true, delay: 0)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(model.state, .hover)
        model.activateHeader()
        XCTAssertEqual(model.state, .expanded)
        model.activateHeader()
        XCTAssertEqual(model.state, .collapsed)
    }
    @MainActor func testPlaybackChangesDoNotInterruptMemoEditing() {
        let model = NotchViewModel()
        model.send(.open)
        model.setMusicPlaying(true)
        XCTAssertEqual(model.state, .expanded)
        XCTAssertTrue(model.musicPlaying)
        model.setMusicPlaying(false)
        XCTAssertEqual(model.state, .expanded)
        XCTAssertFalse(model.musicPlaying)
    }
    @MainActor func testPlaybackOnlyRequestsLayoutWhenStateChanges() {
        let model = NotchViewModel()
        var layouts = 0
        model.onChange = { layouts += 1 }
        model.setMusicPlaying(true)
        model.setMusicPlaying(true)
        model.setMusicPlaying(false)
        XCTAssertEqual(layouts, 2)
        XCTAssertEqual(model.state, .collapsed)
    }
    @MainActor func testMusicIslandStaysVisibleUntilCollapseFinishes() async throws {
        let model = NotchViewModel()
        defer { model.stop() }
        model.setMusicPlaying(true)
        XCTAssertTrue(model.musicIslandVisible)
        model.setMusicPlaying(false, collapseAfter: 0.12)
        XCTAssertFalse(model.musicPlaying)
        XCTAssertTrue(model.musicIslandVisible)
        try await Task.sleep(for: .milliseconds(170))
        XCTAssertFalse(model.musicIslandVisible)
    }
    @MainActor func testPlaybackResumeCancelsPendingIslandHide() async throws {
        let model = NotchViewModel()
        defer { model.stop() }
        model.setMusicPlaying(true)
        model.setMusicPlaying(false, collapseAfter: 0.12)
        model.setMusicPlaying(true)
        try await Task.sleep(for: .milliseconds(170))
        XCTAssertTrue(model.musicPlaying)
        XCTAssertTrue(model.musicIslandVisible)
    }
    private func directory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    @MainActor func testCalendarDenialLeavesOtherModulesAvailable() async {
        let model = CalendarViewModel(service: DeniedCalendar())
        await model.connect()
        XCTAssertFalse(model.authorized); XCTAssertTrue(model.events.isEmpty); XCTAssertFalse(model.requesting)
        model.stop()
    }
    @MainActor func testMemoEditsSurviveRelaunch() throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("memo.json")
        let first = MemoViewModel(url: url)
        first.create(); first.update { $0.text = "지속 저장 테스트"; $0.pinned = true; $0.checklist.append(ChecklistItem(text: "확인")) }; first.flush()
        let second = MemoViewModel(url: url)
        XCTAssertEqual(second.selected?.text, "지속 저장 테스트"); XCTAssertEqual(second.selected?.checklist.count, 1); XCTAssertTrue(second.selected?.pinned ?? false)
    }
    @MainActor func testCorruptedMemoPreventsDestructiveOverwrite() throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("memo.json"), original = Data("corrupted".utf8)
        try original.write(to: url)
        let model = MemoViewModel(url: url); model.create(); model.flush()
        XCTAssertFalse(model.writable); XCTAssertNotNil(model.error); XCTAssertEqual(try Data(contentsOf: url), original)
    }
    @MainActor func testShelfDeduplicatesAndNeverDeletesOriginal() throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let original = dir.appendingPathComponent("original.txt")
        try Data("keep me".utf8).write(to: original)
        let store = dir.appendingPathComponent("shelf.json")
        let model = FileShelfViewModel(service: MockShelf(), url: store)
        model.add([original, original]); XCTAssertEqual(model.items.count, 1)
        model.clear(); XCTAssertTrue(FileManager.default.fileExists(atPath: original.path)); XCTAssertTrue(model.items.isEmpty)
        model.stop()
    }
    @MainActor func testShelfMissingFileKeepsReferenceWithoutCrashing() throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("shelf.json")
        let missing = ShelfItem(bookmark: Data(), originalPath: dir.appendingPathComponent("missing.pdf").path, name: "missing.pdf")
        try LocalStore<[ShelfItem]>(url: url).save([missing])
        let model = FileShelfViewModel(service: MockShelf(), url: url)
        XCTAssertEqual(model.items.count, 1); XCTAssertNil(model.urls[missing.id]); model.stop()
    }
}
