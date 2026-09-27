import AppKit
struct MusicTrack {
    let id: String
    let title: String
    let artist: String
    let duration: Double
    let position: Double
    let isPlaying: Bool
    let receivedAt: Date
    var artwork: NSImage?
    func progress(at date: Date) -> Double { min(duration, max(0, position + (isPlaying ? date.timeIntervalSince(receivedAt) : 0))) }
}
enum MusicProvider: String, CaseIterable, Identifiable {
    case appleMusic = "Apple Music", spotify = "Spotify"
    var id: String { rawValue }
    var bundleID: String { self == .appleMusic ? "com.apple.Music" : "com.spotify.client" }
    var notification: String { self == .appleMusic ? "com.apple.Music.playerInfo" : "com.spotify.client.PlaybackStateChanged" }
}
enum MusicCommand: String { case playPause = "playpause", next = "next track", previous = "previous track" }
