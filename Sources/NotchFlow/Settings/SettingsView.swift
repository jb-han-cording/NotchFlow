import SwiftUI
import EventKit
#if SWIFT_PACKAGE
import NotchFlowCore
#endif

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "일반"
    case appearance = "외관"
    case modules = "모듈"
    case connections = "연결"
    case notifications = "알림"
    case system = "업데이트"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "paintpalette"
        case .modules: return "square.grid.2x2"
        case .connections: return "link"
        case .notifications: return "bell"
        case .system: return "arrow.triangle.2.circlepath"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel
    @ObservedObject var music: MusicViewModel
    @ObservedObject var calendar: CalendarViewModel
    @ObservedObject var updater: UpdateManager
    var shortcutError: String?
    var showOnboarding: (() -> Void)?
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar Navigation
            VStack(alignment: .leading, spacing: 4) {
                Text("설정")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 20)
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                        .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                }

                Spacer()

                Divider()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)

                // Quick Action Buttons
                VStack(spacing: 4) {
                    Button {
                        relaunchApp()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.blue)
                                .frame(width: 20)
                            Text("프로그램 재실행")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 10)
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .help("NotchFlow 앱 재실행")

                    Button {
                        quitApp()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "power")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.red)
                                .frame(width: 20)
                            Text("프로그램 종료")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.red)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 10)
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .help("NotchFlow 앱 종료")
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)

                if let error = model.error {
                    Text(error)
                        .foregroundStyle(.orange)
                        .font(.caption)
                        .padding(12)
                }
            }
            .frame(width: 175)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Right Content Area
            VStack(spacing: 0) {
                Form {
                    switch selectedTab {
                    case .general:
                        generalSection
                    case .appearance:
                        appearanceSection
                    case .modules:
                        modulesSection
                    case .connections:
                        connectionsSection
                    case .notifications:
                        notificationsSection
                    case .system:
                        systemSection
                    }
                }
                .formStyle(.grouped)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 640, minHeight: 480)
        .onAppear {
            model.refreshLogin()
            calendar.refresh()
        }
    }

    @ViewBuilder
    private var generalSection: some View {
        Section("일반 설정 (General)") {
            Toggle("로그인 시 실행", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
            Toggle("상단바에 NotchFlow 표시", isOn: $model.value.showMenuBarIcon)
            Text("끄더라도 프로그램과 노치 기능은 계속 실행됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("마우스를 올리면 화면 펼치기", isOn: $model.value.openOnHover)
            Toggle("클릭하면 펼치기", isOn: $model.value.openOnClick)
            LabeledContent("호버 지연") {
                Slider(value: $model.value.hoverDelay, in: 0.05...1.5)
                Text(model.value.hoverDelay, format: .number.precision(.fractionLength(2))).monospacedDigit()
            }
            LabeledContent("애니메이션 시간") {
                Slider(value: $model.value.animationSpeed, in: 0.1...0.8)
            }
            Picker("전역 단축키", selection: $model.value.shortcut) {
                ForEach(["Option + Space", "Control + Option + Space", "Command + Shift + Space", "Disabled"], id: \.self) { Text($0) }
            }
            if let shortcutError {
                Text(shortcutError).foregroundStyle(.orange).font(.caption)
            }
            Picker("디스플레이", selection: $model.value.screenID) {
                Text("자동 · 노치 화면 우선").tag("")
                ForEach(NSScreen.screens, id: \.localizedName) { screen in Text(screen.localizedName).tag(ScreenService.id(screen)) }
            }
            Button("첫 실행 안내 다시 보기") { showOnboarding?() }
        }
        Section("앱별 자동 숨김") {
            Text("선택한 앱이 활성화되면 노치 패널을 숨깁니다. 다른 앱으로 전환하면 다시 나타납니다.").font(.caption)
            ForEach(model.value.autoHideApps, id: \.self) { id in
                HStack {
                    Text(NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)?.deletingPathExtension().lastPathComponent ?? id)
                    Spacer()
                    Button("제거") { model.value.autoHideApps.removeAll { $0 == id } }
                }
            }
            Button("앱 추가…") {
                let picker = NSOpenPanel()
                picker.allowedContentTypes = [.application]
                picker.allowsMultipleSelection = true
                picker.canChooseDirectories = false
                picker.directoryURL = URL(fileURLWithPath: "/Applications")
                if picker.runModal() == .OK {
                    for url in picker.urls {
                        if let id = Bundle(url: url)?.bundleIdentifier,
                           id != Bundle.main.bundleIdentifier,
                           !model.value.autoHideApps.contains(id) { model.value.autoHideApps.append(id) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var appearanceSection: some View {
        Section("외관 & 스타일 (Appearance)") {
            Picker("테마", selection: $model.value.theme) {
                ForEach(["System", "Dark", "Light"], id: \.self) { Text($0) }
            }
            Picker("이퀄라이저 스타일", selection: Binding(get: { model.value.equalizerColor }, set: { model.value.equalizerColor = $0 })) {
                ForEach(["Blue", "Neon Pink", "Cyan Wave", "Sunset Gradient", "Flame Red", "Monochrome White", "Rainbow"], id: \.self) { style in
                    Text(style).tag(style)
                }
            }
            Toggle("리퀴드 글래스 (Liquid Glass)", isOn: $model.value.liquidGlass)
            if model.value.liquidGlass {
                LabeledContent("리퀴드 글래스 강도") {
                    Slider(value: $model.value.liquidGlassGlassiness, in: 0.05...0.80)
                    Text("\(Int(model.value.liquidGlassGlassiness * 100))%")
                        .monospacedDigit()
                }
            }
            LabeledContent("확장 너비") {
                Slider(value: $model.value.expandedWidth, in: 380...900)
                Text("\(Int(model.value.expandedWidth))")
            }
            LabeledContent("모서리 둥글기") {
                Slider(value: $model.value.cornerRadius, in: 12...40)
            }
            LabeledContent("불투명도") {
                Slider(value: $model.value.opacity, in: 0.75...1)
            }
            Toggle("배경 블러", isOn: $model.value.blur)
        }
    }

    @ViewBuilder
    private var modulesSection: some View {
        Section("모듈 활성화 (Modules)") {
            Toggle("Music", isOn: $model.value.musicEnabled)
            Toggle("Calendar", isOn: $model.value.calendarEnabled)
            Toggle("File Shelf", isOn: $model.value.shelfEnabled)
            Toggle("Memo", isOn: $model.value.memoEnabled)
        }
        Section("파일 선반 자동 정리") {
            Picker("보관 기간", selection: $model.value.shelfRetentionHours) {
                Text("자동 정리 안 함").tag(0)
                Text("1시간").tag(1)
                Text("하루").tag(24)
                Text("일주일").tag(168)
            }
            Text("추가한 시점부터 계산합니다. 기간을 넘긴 항목은 즉시 선반에서 제거되며 원본 파일은 유지됩니다.").font(.caption)
        }
    }

    @ViewBuilder
    private var connectionsSection: some View {
        Section("음악 앱 연결") {
            Toggle("음악 모듈 사용", isOn: $model.value.musicEnabled)

            Picker("음악 앱", selection: $model.value.musicProvider) {
                ForEach(MusicProvider.allCases) { provider in
                    Text(provider.rawValue).tag(provider.rawValue)
                }
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: music.connected ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(music.connected ? .green : .orange)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    Text(music.connected ? "연결 활성화" : "연결 안 됨")
                        .font(.body.weight(.semibold))
                    Text(music.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                music.connect()
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("연결 재시도 / 권한 요청")
                }
            }

            Button {
                music.openPermissionSettings()
            } label: {
                HStack {
                    Image(systemName: "gearshape")
                    Text("macOS 자동화 권한 설정 열기")
                }
            }
        }

        Section("캘린더 연결") {
            Toggle("캘린더 모듈 사용", isOn: $model.value.calendarEnabled)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: calendar.authorized ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(calendar.authorized ? .green : .orange)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    Text(calendarStatusText)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(calendarStatusColor)
                    Text(calendar.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button(calendar.authorization == .notDetermined || calendar.authorization == .writeOnly ? "캘린더 권한 요청" : "권한 다시 확인") {
                    Task { await calendar.connect() }
                }
                .disabled(calendar.authorized)

                Button("macOS 캘린더 권한 설정 열기") {
                    calendar.openPermissionSettings()
                }
            }
        }
    }

    @ViewBuilder
    private var notificationsSection: some View {
        Section("앱 내부 알림 (Notifications)") {
            Toggle("배터리·충전 알림", isOn: $model.value.batteryNotifications)
            Text("전원 연결·분리, 배터리 20%·10% 이하 및 충전 완료를 알려줍니다.").font(.caption)
            Toggle("곡이 바뀌면 음악 화면 펼치기", isOn: $model.value.expandOnTrackChange)
            Text("끄면 곡 변경 시 화면이 자동으로 확장되지 않습니다. 재생 중 다이나믹 아일랜드 표시는 계속 작동합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("일정 알림 (10분 전)", isOn: $model.value.calendarNotifications)
            Toggle("선반 저장 알림", isOn: $model.value.fileNotifications)
            Toggle("메모 저장 알림", isOn: $model.value.memoNotifications)
        }
    }

    @ViewBuilder
    private var systemSection: some View {
        Section("앱 정보") {
            LabeledContent("앱 버전") {
                Text("\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.3.6") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "19"))")
                    .foregroundStyle(.secondary)
            }
        }

        Section("소프트웨어 업데이트") {
            Toggle("자동으로 업데이트 확인", isOn: Binding(
                get: { model.value.automaticUpdateChecks },
                set: { enabled in
                    model.value.automaticUpdateChecks = enabled
                }
            ))
            Text(updater.status)
                .font(.caption)
                .foregroundStyle(Color.secondary)

            HStack {
                Button(updater.checking ? "확인 중…" : "업데이트 확인") {
                    Task { await updater.check() }
                }
                .disabled(updater.checking)

            }

            if !updater.isConfigured {
                Label("Sparkle appcast 주소와 서명 키를 연결하면 활성화됩니다.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Sparkle이 다운로드, 설치, 앱 재실행까지 처리합니다. 기존 설정과 메모는 유지됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var calendarStatusText: String {
        switch calendar.authorization {
        case .fullAccess: return "허용됨 (전체 접근)"
        case .writeOnly: return "쓰기 전용 (읽기 필요)"
        case .denied: return "거부됨"
        case .restricted: return "제한됨 (관리 정책)"
        case .notDetermined: return "미요청"
        @unknown default: return "알 수 없음"
        }
    }

    private var calendarStatusColor: Color {
        switch calendar.authorization {
        case .fullAccess: return .green
        case .denied, .restricted: return .red
        case .writeOnly, .notDetermined: return .orange
        @unknown default: return .secondary
        }
    }

    private func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openCalendarPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    private func relaunchApp() {
        let url = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }

    private func quitApp() {
        NSApp.terminate(nil)
    }
}
