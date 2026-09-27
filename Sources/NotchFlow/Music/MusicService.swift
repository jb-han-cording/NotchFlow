import AppKit
#if SWIFT_PACKAGE
import NotchFlowCore
#endif

protocol MusicProviding { func fetch(_ provider: MusicProvider, command: MusicCommand?, includeArtwork: Bool, completion: @escaping (Result<MusicTrack?, Error>) -> Void) }
struct MusicError: LocalizedError { let message: String; var errorDescription: String? { message } }
final class MusicService: MusicProviding {
    private let queue = DispatchQueue(label: "local.NotchFlow.music", qos: .utility)
    private var scriptCache: [String: NSAppleScript] = [:]
    func fetch(_ provider: MusicProvider, command: MusicCommand? = nil, includeArtwork: Bool = true, completion: @escaping (Result<MusicTrack?, Error>) -> Void) {
        queue.async {
            guard !NSRunningApplication.runningApplications(withBundleIdentifier: provider.bundleID).isEmpty else {
                DispatchQueue.main.async { completion(.failure(MusicError(message: "\(provider.rawValue)을 먼저 실행한 뒤 연결하세요."))) }
                return
            }
            let duration = provider == .spotify ? "(duration of current track) / 1000" : "duration of current track"
            let artwork = provider == .appleMusic && includeArtwork ? "try\nset coverData to raw data of artwork 1 of current track\nend try" : ""
            let source = """
            with timeout of 5 seconds
                tell application id "\(provider.bundleID)"
                    \(command?.rawValue ?? "")
                    if player state is stopped then return {}
                    set coverData to ""
                    \(artwork)
                    return {name of current track, artist of current track, \(duration), player position, (player state is playing), coverData}
                end tell
            end timeout
            """
            let cacheKey = "\(provider.rawValue)|\(command?.rawValue ?? "status")|\(includeArtwork)"
            let script: NSAppleScript
            if let cached = self.scriptCache[cacheKey] {
                script = cached
            } else if let compiled = NSAppleScript(source: source) {
                self.scriptCache[cacheKey] = compiled
                script = compiled
            } else {
                DispatchQueue.main.async { completion(.failure(MusicError(message: "음악 연결 스크립트를 생성할 수 없습니다."))) }
                return
            }
            var error: NSDictionary?
            let result = script.executeAndReturnError(&error)
            if let error {
                let code = error[NSAppleScript.errorNumber] as? Int ?? 0
                DispatchQueue.main.async { completion(.failure(MusicError(message: code == -1743 ? "자동화 접근이 거부되었습니다. 시스템 설정 → 개인정보 보호 및 보안 → 자동화를 확인하세요." : "플레이어 정보를 읽을 수 없습니다. 다시 연결하세요. (\(code))"))) }
                return
            }
            guard result.numberOfItems >= 5 else { DispatchQueue.main.async { completion(.success(nil)) }; return }
            let title = result.atIndex(1)?.stringValue ?? ""
            let artist = result.atIndex(2)?.stringValue ?? ""
            let track = MusicTrack(id: title + "\u{1f}" + artist, title: title, artist: artist, duration: result.atIndex(3)?.doubleValue ?? 0, position: result.atIndex(4)?.doubleValue ?? 0, isPlaying: result.atIndex(5)?.booleanValue ?? false, receivedAt: Date(), artwork: result.atIndex(6).flatMap { NSImage(data: $0.data) })
            DispatchQueue.main.async { completion(.success(track)) }
        }
    }
}
