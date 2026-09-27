import SwiftUI
#if SWIFT_PACKAGE
import NotchFlowCore
#endif

enum Module: String, CaseIterable, Identifiable {
    case dashboard = "Overview", music = "Music", calendar = "Calendar", shelf = "Shelf", memo = "Memo", timer = "Timer"
    var id: String { rawValue }
    var icon: String { switch self { case .dashboard: return "square.grid.2x2"; case .music: return "waveform"; case .calendar: return "calendar"; case .shelf: return "tray"; case .memo: return "square.and.pencil"; case .timer: return "timer" } }
}
@MainActor final class AppState: ObservableObject {
    let notch = NotchViewModel()
    let settings = SettingsViewModel()
    let music = MusicViewModel()
    let calendar = CalendarViewModel()
    let shelf = FileShelfViewModel()
    let memo = MemoViewModel()
    let timer = FocusTimer()
    let notifications = NotificationManager()
    @Published var selectedModule: Module = .dashboard
    @Published var shortcutError: String?
    var showSettings: (() -> Void)?
    var showOnboarding: (() -> Void)?
    init() {
        timer.onComplete = { [weak self] in
            self?.notifications.post(NotchNotification(kind: .timer, title: "타이머 완료", subtitle: "설정한 시간이 끝났습니다", icon: "timer", duration: 5, priority: 10))
            NSSound.beep()
        }
        music.onTrackChanged = { [weak self] track in
            guard let self, self.settings.value.musicEnabled, self.settings.value.expandOnTrackChange else { return }
            self.notifications.post(NotchNotification(kind: .music, title: track.title, subtitle: track.artist, icon: "music.note", priority: 1))
        }
        calendar.onReminder = { [weak self] event in
            guard let self, self.settings.value.calendarEnabled, self.settings.value.calendarNotifications else { return }
            let minutes = max(1, Int(ceil(event.start.timeIntervalSinceNow / 60)))
            self.notifications.post(NotchNotification(kind: .calendar, title: event.title, subtitle: "\(minutes)분 후 시작", icon: "calendar", duration: 5, priority: 10))
        }
        shelf.onAdded = { [weak self] count in
            guard let self, self.settings.value.fileNotifications else { return }
            self.notifications.post(NotchNotification(kind: .files, title: "선반에 추가됨", subtitle: "\(count)개 파일 · 원본 위치 유지", icon: "tray.and.arrow.down", priority: 2))
        }
        memo.onSaved = { [weak self] in
            guard let self, self.settings.value.memoNotifications else { return }
            self.notifications.post(NotchNotification(kind: .memo, title: "메모 저장됨", subtitle: "이 Mac에 안전하게 보관됩니다", icon: "checkmark.circle", duration: 1.5))
        }
        notifications.onPresentation = { [weak self] showing in self?.notch.send(showing ? .notify : .endNotification) }
        calendar.enabled = settings.value.calendarEnabled
    }
    func isEnabled(_ module: Module) -> Bool {
        switch module { case .dashboard, .timer: return true; case .music: return settings.value.musicEnabled; case .calendar: return settings.value.calendarEnabled; case .shelf: return settings.value.shelfEnabled; case .memo: return settings.value.memoEnabled }
    }
    func stop() { memo.flush(); music.disconnect(); calendar.stop(); shelf.stop(); notifications.stop(); QuickLookService.shared.close() }
}
