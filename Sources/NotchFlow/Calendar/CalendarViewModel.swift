import AppKit
import EventKit
import Combine
#if SWIFT_PACKAGE
import NotchFlowCore
#endif
@MainActor final class CalendarViewModel: ObservableObject {
    @Published private(set) var events: [CalendarEvent] = []
    @Published private(set) var authorized = false
    @Published private(set) var status = "캘린더를 연결하면 오늘의 일정을 볼 수 있습니다."
    @Published private(set) var requesting = false
    @Published private(set) var authorization: EKAuthorizationStatus = .notDetermined
    var onReminder: ((CalendarEvent) -> Void)?
    var enabled = true { didSet { enabled ? refresh() : stopTimers() } }
    private let service: CalendarProviding
    private var observers: [NSObjectProtocol] = []
    private var reminderTimer: Timer?
    private var midnightTimer: Timer?
    private var delivered: Set<String> = []
    private var requestHint: Task<Void, Never>?
    init(service: CalendarProviding? = nil) {
        self.service = service ?? CalendarService()
        observers.append(NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.refresh() } })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.refresh() } })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.refresh() } })
        refresh()
    }
    func connect() async {
        guard enabled, !requesting else { return }
        refresh()
        // macOS does not display the permission dialog again after a denial.
        guard authorization == .notDetermined || authorization == .writeOnly else { return }
        requesting = true
        status = "macOS 캘린더 권한을 확인하고 있습니다. 권한 창에서 전체 접근을 허용하세요."
        requestHint = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled, let self, self.requesting else { return }
            self.status = "macOS 응답을 기다리고 있습니다. 권한 창이 보이지 않으면 아래의 권한 설정 열기를 사용하세요."
        }
        defer { requesting = false; requestHint?.cancel(); requestHint = nil }
        do {
            let granted = try await service.requestAccess()
            AppLog.permissions.info("Calendar Permission granted: \(granted)")
            requesting = false
            refresh()
            if !granted && authorization == .notDetermined {
                status = "macOS가 권한 요청을 완료하지 못했습니다. 앱을 Applications에 설치한 뒤 다시 실행하거나 권한 설정을 확인하세요."
            }
        } catch {
            let error = error as NSError
            AppLog.permissions.error("Calendar request failed: \(error.domain, privacy: .public) \(error.code)")
            status = "캘린더 권한 요청에 실패했습니다 (오류 \(error.code)). 권한 설정을 확인한 뒤 다시 시도하세요."
        }
    }
    func refresh() {
        guard enabled, !requesting else { return }
        authorization = service.authorization
        authorized = authorization == .fullAccess
        guard authorized else {
            events = []; stopTimers()
            switch authorization {
            case .notDetermined: status = "캘린더를 연결하면 오늘의 일정을 볼 수 있습니다."
            case .restricted: status = "이 Mac의 관리 정책으로 캘린더 접근이 제한되어 있습니다. 기기 관리자에게 문의하세요."
            case .writeOnly: status = "현재 일정 추가만 허용되어 있습니다. 일정을 표시하려면 전체 접근이 필요합니다."
            default: status = "캘린더 접근이 거부되어 요청 창이 다시 뜨지 않습니다. 시스템 설정 → 개인정보 보호 및 보안 → 캘린더에서 NotchFlow를 허용하세요."
            }
            return
        }
        let now = Date(), start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        events = service.events(from: start, to: end).sorted { $0.start < $1.start }
        status = events.isEmpty ? "오늘은 예정된 일정이 없습니다." : "오늘 \(events.count)개의 일정"
        scheduleReminder(now: now)
        midnightTimer?.invalidate()
        midnightTimer = Timer(fire: end, interval: 0, repeats: false) { [weak self] _ in Task { @MainActor in self?.delivered.removeAll(); self?.refresh() } }
        if let midnightTimer { RunLoop.main.add(midnightTimer, forMode: .common) }
    }
    var next: CalendarEvent? { CalendarEvent.upcoming(events.filter { !$0.isAllDay }, at: Date()).first }
    private func scheduleReminder(now: Date) {
        reminderTimer?.invalidate()
        let candidates = events.filter { !$0.isAllDay && $0.start > now && !delivered.contains($0.id) }.sorted { $0.start < $1.start }
        guard let event = candidates.first else { return }
        let fire = max(now.addingTimeInterval(0.5), event.start.addingTimeInterval(-600))
        reminderTimer = Timer(fire: fire, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.enabled else { return }
                self.delivered.insert(event.id)
                if event.start > Date(), self.service.authorization == .fullAccess { self.onReminder?(event) }
                self.scheduleReminder(now: Date())
            }
        }
        if let reminderTimer { RunLoop.main.add(reminderTimer, forMode: .common) }
    }
    private func stopTimers() { reminderTimer?.invalidate(); midnightTimer?.invalidate() }
    func stop() {
        requestHint?.cancel()
        stopTimers()
        observers.forEach { NotificationCenter.default.removeObserver($0); NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }
    func openCalendar() { if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") { NSWorkspace.shared.open(url) } }
    func openPermissionSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
        if !NSWorkspace.shared.open(url) {
            if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systempreferences") {
                NSWorkspace.shared.open(app)
            }
            status = "시스템 설정 → 개인정보 보호 및 보안 → 캘린더에서 NotchFlow의 전체 접근을 허용하세요."
        }
    }
}
