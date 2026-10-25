import AppKit
import Combine
import XCTest
@testable import NotchFlow

@MainActor final class MusicPollingTests: XCTestCase {
    private final class Service: MusicProviding {
        var commands: [MusicCommand?] = []
        var completions: [(Result<MusicTrack?, Error>) -> Void] = []
        func fetch(_ provider: MusicProvider, command: MusicCommand?, includeArtwork: Bool,
                   completion: @escaping (Result<MusicTrack?, Error>) -> Void) {
            commands.append(command)
            completions.append(completion)
        }
        func finish(_ track: MusicTrack?) async {
            completions.removeFirst()(.success(track))
            // The production model applies results in a main-actor Task.
            try? await Task.sleep(for: .milliseconds(20))
        }
    }
    private func track(position: Double = 10) -> MusicTrack {
        MusicTrack(id: "song", title: "Song", artist: "Artist", duration: 180,
                   position: position, isPlaying: true, receivedAt: Date(),
                   artwork: NSImage(size: NSSize(width: 1, height: 1)))
    }
    func testUnchangedPollDoesNotPublishOrDisableControls() async {
        let service = Service()
        let subject = MusicViewModel(service: service)
        defer { subject.disconnect() }
        subject.connect()
        await service.finish(track())
        var changes = 0
        let observation = subject.objectWillChange.sink { changes += 1 }
        defer { observation.cancel() }
        for _ in 0..<3 {
            subject.refresh(includeArtwork: false)
            XCTAssertFalse(subject.busy)
            await service.finish(track())
        }
        XCTAssertEqual(changes, 0, "Polling must not flash disabled controls or republish unchanged status")
    }
    func testCommandDuringPollIsExecutedAfterPoll() async {
        let service = Service()
        let model = MusicViewModel(service: service)
        defer { model.disconnect() }
        model.connect()
        await service.finish(track())
        model.refresh(includeArtwork: false)
        model.refresh(command: .next)
        XCTAssertTrue(model.busy)
        XCTAssertEqual(service.commands.count, 2)
        await service.finish(track())
        XCTAssertEqual(service.commands.last!, .next)
        await service.finish(track())
        XCTAssertFalse(model.busy)
    }
    func testSeekingIsNotSuppressedAsAnUnchangedPoll() async {
        let service = Service()
        let model = MusicViewModel(service: service)
        defer { model.disconnect() }
        model.connect()
        await service.finish(track())
        model.refresh(includeArtwork: false)
        await service.finish(track(position: 90))
        XCTAssertEqual(model.track?.position, 90)
    }
    func testDisconnectDropsQueuedCommandAndLateResult() async {
        let service = Service()
        let model = MusicViewModel(service: service)
        model.connect()
        await service.finish(track())
        model.refresh(includeArtwork: false)
        model.refresh(command: .playPause)
        model.disconnect()
        await service.finish(track())
        XCTAssertEqual(service.commands.count, 2)
        XCTAssertNil(model.track)
        XCTAssertFalse(model.busy)
        XCTAssertFalse(model.connected)
    }
}
