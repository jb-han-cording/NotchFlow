import Foundation
import MediaPlayer
import AppKit

@MainActor final class SystemMediaObserver {
    private var timer: Timer?
    private var lastPlayingState: Bool = false
    private var lastTrackID: String?
    private var lastTrackPlayingState: Bool?
    var onPlayingStateChanged: ((Bool) -> Void)?
    var onTrackChanged: ((MusicTrack?) -> Void)?

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkPlayingState() }
        }
        timer?.tolerance = 0.2
        checkPlayingState()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkPlayingState() {
        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo

        let playbackRate = (info?["MPNowPlayingPlaybackRate"] as? NSNumber)?.doubleValue ?? 0
        let isPlayingRate = playbackRate > 0
        let state = (info?["MPNowPlayingPlaybackState"] as? NSNumber)?.intValue ?? 0
        let isPlayingState = state == 1 // .playing
        let currentlyPlaying = isPlayingRate || isPlayingState

        if currentlyPlaying != lastPlayingState {
            lastPlayingState = currentlyPlaying
            onPlayingStateChanged?(currentlyPlaying)
        }

        let title = info?[MPMediaItemPropertyTitle] as? String ?? ""
        let artist = info?[MPMediaItemPropertyArtist] as? String ?? ""
        let album = info?[MPMediaItemPropertyAlbumTitle] as? String ?? ""
        let duration = (info?[MPMediaItemPropertyPlaybackDuration] as? NSNumber)?.doubleValue ?? 0
        let position = (info?["MPNowPlayingElapsedPlaybackTime"] as? NSNumber)?.doubleValue ?? 0
        let persistentID = (info?[MPMediaItemPropertyPersistentID] as? NSNumber)?.uint64Value
        let id = persistentID.map(String.init) ?? "\(title)\u{1f}\(artist)\u{1f}\(album)"

        let hasMetadata = !title.isEmpty || !artist.isEmpty || !album.isEmpty
        let nextTrack: MusicTrack?
        if hasMetadata {
            let artwork = (info?[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork)?.image(at: NSSize(width: 512, height: 512))
            nextTrack = MusicTrack(
                id: id,
                title: title.isEmpty ? album : title,
                artist: artist.isEmpty ? "재생 중인 오디오" : artist,
                duration: duration,
                position: position,
                isPlaying: currentlyPlaying,
                receivedAt: Date(),
                artwork: artwork
            )
        } else {
            nextTrack = nil
        }

        if nextTrack?.id != lastTrackID || nextTrack?.isPlaying != lastTrackPlayingState {
            lastTrackID = nextTrack?.id
            lastTrackPlayingState = nextTrack?.isPlaying
            onTrackChanged?(nextTrack)
        }
    }
}
