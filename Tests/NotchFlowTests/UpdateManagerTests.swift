import Foundation
import XCTest
@testable import NotchFlow

private struct StubUpdateFetcher: UpdateFetching {
    let data: Data
    let statusCode: Int

    func data(from url: URL) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Length": "\(data.count)"]
        )!
        return (data, response)
    }
}

final class UpdateManagerTests: XCTestCase {
    @MainActor
    func testNewerBuildBecomesAvailable() async throws {
        let data = try JSONEncoder().encode(UpdateManifest(
            version: "0.4.0",
            build: 5,
            dmgURL: URL(string: "https://example.com/NotchFlow.dmg")!,
            sha256: String(repeating: "a", count: 64),
            releaseNotes: "새 기능"
        ))
        let manager = UpdateManager(
            feedURL: URL(string: "https://example.com/update.json")!,
            currentBuild: 4,
            fetcher: StubUpdateFetcher(data: data, statusCode: 200)
        )

        await manager.check()

        XCTAssertEqual(manager.available?.build, 5)
        XCTAssertTrue(manager.status.contains("0.4.0"))
    }

    @MainActor
    func testCurrentBuildReportsLatest() async throws {
        let data = try JSONEncoder().encode(UpdateManifest(
            version: "0.3.0",
            build: 4,
            dmgURL: URL(string: "https://example.com/NotchFlow.dmg")!,
            sha256: String(repeating: "b", count: 64),
            releaseNotes: nil
        ))
        let manager = UpdateManager(
            feedURL: URL(string: "https://example.com/update.json")!,
            currentBuild: 4,
            fetcher: StubUpdateFetcher(data: data, statusCode: 200)
        )

        await manager.check()

        XCTAssertNil(manager.available)
        XCTAssertEqual(manager.status, "현재 최신 버전을 사용 중입니다.")
    }

    @MainActor
    func testRejectsInsecureDownloadURL() async throws {
        let data = try JSONEncoder().encode(UpdateManifest(
            version: "0.4.0",
            build: 5,
            dmgURL: URL(string: "http://example.com/NotchFlow.dmg")!,
            sha256: String(repeating: "c", count: 64),
            releaseNotes: nil
        ))
        let manager = UpdateManager(
            feedURL: URL(string: "https://example.com/update.json")!,
            currentBuild: 4,
            fetcher: StubUpdateFetcher(data: data, statusCode: 200)
        )

        await manager.check()

        XCTAssertNil(manager.available)
        XCTAssertTrue(manager.status.contains("올바르지 않습니다"))
    }

    @MainActor
    func testManualCheckExplainsMissingFeed() async {
        let manager = UpdateManager(feedURL: nil, currentBuild: 4)
        await manager.check()
        XCTAssertFalse(manager.isConfigured)
        XCTAssertTrue(manager.status.contains("설정되지 않았습니다"))
    }
}
