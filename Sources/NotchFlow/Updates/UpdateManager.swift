import AppKit
import Combine
import CryptoKit
import Foundation

struct UpdateManifest: Codable, Equatable {
    let version: String
    let build: Int
    let dmgURL: URL
    let sha256: String
    let releaseNotes: String?
}

protocol UpdateFetching {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: UpdateFetching {}

private func configuredUpdateFeedURL(bundle: Bundle = .main) -> URL? {
    guard let value = bundle.object(forInfoDictionaryKey: "NotchFlowUpdateFeedURL") as? String else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return URL(string: trimmed)
}

@MainActor final class UpdateManager: ObservableObject {
    @Published private(set) var available: UpdateManifest?
    @Published private(set) var status = "업데이트를 확인하지 않았습니다."
    @Published private(set) var checking = false
    @Published private(set) var downloading = false

    private let feedURL: URL?
    private let fetcher: UpdateFetching
    private let currentBuild: Int

    init(
        feedURL: URL? = configuredUpdateFeedURL(),
        currentBuild: Int = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0") ?? 0,
        fetcher: UpdateFetching = URLSession.shared
    ) {
        self.feedURL = feedURL
        self.currentBuild = currentBuild
        self.fetcher = fetcher
    }

    var isConfigured: Bool { feedURL != nil }

    func check(silent: Bool = false) async {
        guard let feedURL else {
            if !silent { status = "업데이트 배포 주소가 아직 설정되지 않았습니다." }
            return
        }
        guard feedURL.scheme?.lowercased() == "https" else {
            status = "업데이트 주소는 HTTPS여야 합니다."
            return
        }
        checking = true
        defer { checking = false }
        do {
            let (data, response) = try await fetcher.data(from: feedURL)
            try validate(response: response, maximumBytes: 1_000_000, actualBytes: data.count)
            let manifest = try JSONDecoder().decode(UpdateManifest.self, from: data)
            guard manifest.dmgURL.scheme?.lowercased() == "https",
                  manifest.sha256.range(of: "^[0-9a-fA-F]{64}$", options: .regularExpression) != nil else {
                throw UpdateError.invalidManifest
            }
            if manifest.build > currentBuild {
                available = manifest
                status = "NotchFlow \(manifest.version) 업데이트를 사용할 수 있습니다."
            } else {
                available = nil
                status = "현재 최신 버전을 사용 중입니다."
            }
        } catch {
            if !silent { status = "업데이트 확인에 실패했습니다: \(error.localizedDescription)" }
        }
    }

    func downloadAndOpen() async {
        guard let manifest = available, !downloading else { return }
        downloading = true
        status = "업데이트를 다운로드하고 있습니다…"
        defer { downloading = false }
        do {
            let (data, response) = try await fetcher.data(from: manifest.dmgURL)
            try validate(response: response, maximumBytes: 250_000_000, actualBytes: data.count)
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard digest.caseInsensitiveCompare(manifest.sha256) == .orderedSame else {
                throw UpdateError.checksumMismatch
            }
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("NotchFlow-\(manifest.version)-\(manifest.build).dmg")
            try data.write(to: destination, options: .atomic)
            guard NSWorkspace.shared.open(destination) else { throw UpdateError.cannotOpen }
            status = "다운로드를 검증했습니다. 열린 창에서 NotchFlow를 Applications로 옮겨 업데이트하세요. 설정은 그대로 유지됩니다."
        } catch {
            status = "업데이트 다운로드에 실패했습니다: \(error.localizedDescription)"
        }
    }

    private func validate(response: URLResponse, maximumBytes: Int, actualBytes: Int) throws {
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw UpdateError.invalidResponse
        }
        guard actualBytes <= maximumBytes,
              response.expectedContentLength <= 0 || response.expectedContentLength <= Int64(maximumBytes) else {
            throw UpdateError.fileTooLarge
        }
    }
}

private enum UpdateError: LocalizedError {
    case invalidResponse, invalidManifest, checksumMismatch, fileTooLarge, cannotOpen
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "서버 응답이 올바르지 않습니다."
        case .invalidManifest: return "업데이트 정보가 올바르지 않습니다."
        case .checksumMismatch: return "다운로드한 파일의 무결성 검증에 실패했습니다."
        case .fileTooLarge: return "업데이트 파일이 허용 크기를 초과했습니다."
        case .cannotOpen: return "다운로드한 설치 파일을 열 수 없습니다."
        }
    }
}
