import AppKit
import Combine
@MainActor final class MusicViewModel: ObservableObject {
    @Published var provider: MusicProvider = .appleMusic { didSet { disconnect() } }
    @Published private(set) var track: MusicTrack?
    private(set) var lastTrack: MusicTrack?
    @Published private(set) var status = "플레이어를 선택하고 연결하세요."
    @Published private(set) var connected = false
    @Published private(set) var busy = false
    var onTrackChanged: ((MusicTrack) -> Void)?
    private let service: MusicProviding
    private var observer: NSObjectProtocol?
    private var pollTimer: Timer?
    private var generation = 0
    private var retriedArtworkTrackID: String?
    private var providerTrack: MusicTrack?
    private var externalTrack: MusicTrack?
    init(service: MusicProviding = MusicService()) { self.service = service }
    func connect() {
        disconnect()
        connected = true
        AppLog.app.info("Music Provider: \(self.provider.rawValue, privacy: .public)")
        observer = DistributedNotificationCenter.default().addObserver(forName: Notification.Name(provider.notification), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        let timer = Timer(timeInterval: 1.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh(includeArtwork: false) }
        }
        timer.tolerance = 0.2
        pollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        refresh()
    }
    func disconnect() {
        generation += 1
        if let observer { DistributedNotificationCenter.default().removeObserver(observer) }
        pollTimer?.invalidate()
        pollTimer = nil
        observer = nil; connected = false; busy = false; providerTrack = nil; externalTrack = nil; track = nil; lastTrack = nil; retriedArtworkTrackID = nil
    }

    /// Uses the system-wide Now Playing metadata as a fallback for any audio-capable app.
    func updateExternalTrack(_ externalTrack: MusicTrack?) {
        self.externalTrack = externalTrack
        guard providerTrack == nil else { return }
        if let externalTrack {
            let previousID = track?.id
            if externalTrack.id != previousID || externalTrack.isPlaying != track?.isPlaying {
                lastTrack = externalTrack
                track = externalTrack
                if externalTrack.id != previousID { onTrackChanged?(externalTrack) }
            }
            status = "시스템 미디어 연결됨"
        } else if track != nil {
            track = nil
            status = "재생 중인 오디오가 없습니다."
        }
    }
    func openPlayer() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: provider.bundleID) else {
            status = "\(provider.rawValue)이 설치되어 있지 않습니다."
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { [weak self] _, error in
            guard let error else { return }
            Task { @MainActor in self?.status = "\(self?.provider.rawValue ?? "음악 앱")을 열 수 없습니다: \(error.localizedDescription)" }
        }
    }
    func openPermissionSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") else { return }
        if !NSWorkspace.shared.open(url) {
            status = "시스템 설정 → 개인정보 보호 및 보안 → 자동화에서 NotchFlow를 허용하세요."
        }
    }
    func refresh(command: MusicCommand? = nil, includeArtwork: Bool = true) {
        guard connected, !busy else { return }
        busy = true
        let request = generation
        service.fetch(provider, command: command, includeArtwork: includeArtwork) { [weak self] result in
            Task { @MainActor in
                guard let self, request == self.generation else { return }
                self.busy = false
                switch result {
                case .success(var next):
                    self.providerTrack = next
                    let previous = self.track?.id
                    if next?.id == previous, next?.artwork == nil {
                        next?.artwork = self.track?.artwork
                    }
                    if let current = self.track,
                       let next,
                       command == nil,
                       !includeArtwork,
                       next.id == current.id,
                       next.isPlaying == current.isPlaying,
                       Date().timeIntervalSince(current.receivedAt) < 15 {
                        // TimelineView advances progress locally. Avoid
                        // republishing the same track on every background poll.
                        self.status = "\(self.provider.rawValue) 연결됨"
                        return
                    }
                    if let next { self.lastTrack = next }
                    self.track = next ?? self.externalTrack
                    self.status = next == nil
                        ? (self.externalTrack == nil ? "재생 중인 음악이 없습니다." : "시스템 미디어 연결됨")
                        : "\(self.provider.rawValue) 연결됨"
                    if let next, next.id != previous {
                        self.onTrackChanged?(next)
                        if next.artwork == nil && self.retriedArtworkTrackID != next.id {
                            self.retriedArtworkTrackID = next.id
                            Task {
                                try? await Task.sleep(for: .milliseconds(700))
                                guard self.track?.id == next.id else { return }
                                self.refresh()
                            }
                        }
                    }
                case .failure(let error):
                    self.providerTrack = nil
                    self.track = self.externalTrack
                    self.status = self.externalTrack == nil ? error.localizedDescription : "시스템 미디어 연결됨"
                }
            }
        }
    }
}
