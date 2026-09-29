import SwiftUI
import Combine
import IOKit.ps
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
    private let battery = BatteryObserver()
    private var featureSubscriptions = Set<AnyCancellable>()
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
        settings.$value.map(\.shelfRetentionHours).removeDuplicates()
            .sink { [weak self] in self?.shelf.configureCleanup(hours: $0) }
            .store(in: &featureSubscriptions)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.shelf.configureCleanup(hours: self.settings.value.shelfRetentionHours)
            }.store(in: &featureSubscriptions)
        battery.onNotice = { [weak self] title, detail, icon in
            guard let self, self.settings.value.batteryNotifications else { return }
            self.notifications.post(NotchNotification(kind: .battery, title: title, subtitle: detail, icon: icon, duration: 4, priority: 5))
        }
        battery.start()
    }
    func isEnabled(_ module: Module) -> Bool {
        switch module { case .dashboard, .timer: return true; case .music: return settings.value.musicEnabled; case .calendar: return settings.value.calendarEnabled; case .shelf: return settings.value.shelfEnabled; case .memo: return settings.value.memoEnabled }
    }
    func stop() { battery.stop(); featureSubscriptions.removeAll(); memo.flush(); music.disconnect(); calendar.stop(); shelf.stop(); notifications.stop(); QuickLookService.shared.close() }
}

@MainActor private final class BatteryObserver {
    var onNotice: ((String, String, String) -> Void)?
    private var source: CFRunLoopSource?
    private var previous: (ac: Bool, percent: Int)?
    private var notifiedLevels = Set<Int>()

    func start() {
        readState()
        let context = Unmanaged.passUnretained(self).toOpaque()
        source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            MainActor.assumeIsolated {
                Unmanaged<BatteryObserver>.fromOpaque(context).takeUnretainedValue().readState()
            }
        }, context)?.takeRetainedValue()
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
    }

    func stop() {
        if let source { CFRunLoopSourceInvalidate(source) }
        source = nil
    }

    private func readState() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return }
        for item in sources {
            guard let data = IOPSGetPowerSourceDescription(info, item)?.takeUnretainedValue() as? [String: Any],
                  data[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = data[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = data[kIOPSMaxCapacityKey] as? Int, maximum > 0 else { continue }
            let percent = min(100, max(0, current * 100 / maximum))
            let ac = data[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            defer { previous = (ac, percent) }
            guard let previous else { return }
            if ac { notifiedLevels.removeAll() }
            if previous.ac != ac {
                onNotice?(ac ? "전원이 연결되었습니다" : "배터리로 사용 중", "배터리 \(percent)%", ac ? "battery.100.bolt" : "battery.100")
            } else if ac && percent == 100 && previous.percent < 100 {
                onNotice?("충전 완료", "배터리 100%", "battery.100")
            }
            if !ac {
                let level = percent <= 10 ? 10 : percent <= 20 ? 20 : nil
                if let level, !notifiedLevels.contains(level) {
                    notifiedLevels.insert(level)
                    if level == 10 { notifiedLevels.insert(20) }
                    onNotice?("배터리가 부족합니다", "배터리 \(percent)% · 충전기를 연결해 주세요", "battery.25")
                }
            }
            return
        }
    }
}
