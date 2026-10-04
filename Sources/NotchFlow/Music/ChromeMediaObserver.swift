import AppKit
import Foundation

@MainActor final class ChromeMediaObserver {
    private var timer: Timer?
    private let queue = DispatchQueue(label: "local.NotchFlow.chrome-media", qos: .utility)
    private var lastID: String?
    private var currentPlaying: Bool?
    var onTrackChanged: ((MusicTrack?) -> Void)?

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        timer?.tolerance = 0.3
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        queue.async { [weak self] in
            let result = Self.readActiveYouTubeTab()
            Task { @MainActor in
                guard let self else { return }
                let track = Self.makeTrack(from: result)
                if track?.id != self.lastID || track?.isPlaying != self.currentPlaying {
                    self.lastID = track?.id
                    self.currentPlaying = track?.isPlaying
                    self.onTrackChanged?(track)
                }
            }
        }
    }

    private nonisolated static func readActiveYouTubeTab() -> String? {
        guard let script = NSAppleScript(source: """
        tell application "Google Chrome"
            if (count of windows) is 0 then return ""
            set activeTab to active tab of front window
            set tabURL to URL of activeTab
            if tabURL does not contain "youtube.com" and tabURL does not contain "youtu.be" then return ""
            set tabTitle to title of activeTab
            return tabTitle & "|||" & tabURL & "|||fallback"
        end tell
        """) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil, let value = result.stringValue, !value.isEmpty else { return nil }
        return value
    }

    private nonisolated static func makeTrack(from value: String?) -> MusicTrack? {
        guard let value else { return nil }
        let parts = value.components(separatedBy: "|||")
        guard parts.count >= 3 else { return nil }
        let title = parts[0].replacingOccurrences(of: " - YouTube", with: "")
        guard !title.isEmpty else { return nil }
        let state = parts.dropFirst(2)
        let permissionFallback = state.contains("permission") || state.contains("fallback")
        let hasVideo = state.first == "1"
        guard hasVideo || permissionFallback else { return nil }
        let isPlaying = permissionFallback || state.dropFirst().first == "1"
        let position = state.dropFirst(2).first.flatMap { Double($0) } ?? 0
        let duration = state.dropFirst(3).first.flatMap { Double($0) } ?? 0
        return MusicTrack(id: "youtube|\(parts[1])", title: title, artist: "YouTube", duration: duration, position: position, isPlaying: isPlaying, receivedAt: Date(), artwork: nil)
    }
}
