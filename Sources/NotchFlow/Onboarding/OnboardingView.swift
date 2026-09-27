import EventKit
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var music: MusicViewModel
    @ObservedObject var calendar: CalendarViewModel
    let finish: () -> Void
    @State private var step = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule().fill(index <= step ? Color.notchBlue : Color.secondary.opacity(0.22))
                        .frame(width: index == step ? 34 : 18, height: 5)
                }
            }.padding(.top, 22)

            Group {
                switch step {
                case 0: welcome
                case 1: musicStep
                case 2: calendarStep
                default: completion
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 42)

            Divider()
            HStack {
                if step > 0 { Button("이전") { step -= 1 } }
                Spacer()
                if step < 3 {
                    Button("건너뛰기") { finish() }.buttonStyle(.plain).foregroundStyle(.secondary)
                    Button("계속") { step += 1 }.buttonStyle(NotchActionButtonStyle(prominent: true))
                } else {
                    Button("시작하기") { finish() }.buttonStyle(NotchActionButtonStyle(prominent: true))
                }
            }.padding(20)
        }
        .frame(width: 620, height: 440)
    }

    private var welcome: some View {
        VStack(spacing: 18) {
            Image(systemName: "macbook.and.iphone").font(.system(size: 54)).foregroundStyle(.notchBlue)
            Text("NotchFlow에 오신 것을 환영합니다").font(.title.bold())
            Text("음악과 일정을 노치에서 확인할 수 있도록 두 가지 권한을 차례로 점검합니다.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 430)
            Label("데이터는 이 Mac에만 저장되며 외부로 전송되지 않습니다.", systemImage: "lock.shield")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private var musicStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepTitle("음악 연결", icon: "music.note")
            diagnosticRow(
                title: musicReady ? "음악 연결 준비 완료" : "음악 연결 확인 필요",
                detail: music.status,
                ready: musicReady
            )
            Text("NotchFlow는 선택한 음악 앱의 곡 정보와 재생 제어를 위해 macOS 자동화 권한을 사용합니다.")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Button("음악 앱 열고 연결") {
                    music.openPlayer()
                    Task {
                        try? await Task.sleep(for: .milliseconds(900))
                        music.connect()
                    }
                }.buttonStyle(NotchActionButtonStyle(prominent: true))
                Button("자동화 권한 설정") { music.openPermissionSettings() }
            }
        }
    }

    private var calendarStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepTitle("캘린더 연결", icon: "calendar")
            diagnosticRow(
                title: calendar.authorized ? "캘린더 전체 접근 허용됨" : calendarAuthorizationTitle,
                detail: calendar.status,
                ready: calendar.authorized
            )
            Text("일정은 이 Mac에서만 읽으며 서버로 전송하지 않습니다.")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Button(calendar.authorization == .notDetermined || calendar.authorization == .writeOnly ? "캘린더 권한 요청" : "다시 확인") {
                    Task { await calendar.connect() }
                }.buttonStyle(NotchActionButtonStyle(prominent: true))
                Button("캘린더 권한 설정") { calendar.openPermissionSettings() }
            }
        }
    }

    private var completion: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 58)).foregroundStyle(.notchBlue)
            Text("준비가 완료되었습니다").font(.title.bold())
            Text("권한 상태는 설정 → 시스템 제어에서 언제든 다시 진단할 수 있습니다.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 9) {
                Label(musicReady ? "음악 연결 준비됨" : "음악 연결은 나중에 설정 가능", systemImage: musicReady ? "checkmark.circle" : "exclamationmark.circle")
                Label(calendar.authorized ? "캘린더 연결됨" : "캘린더 연결은 나중에 설정 가능", systemImage: calendar.authorized ? "checkmark.circle" : "exclamationmark.circle")
            }.font(.callout)
        }
    }

    private func stepTitle(_ title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title).foregroundStyle(.notchBlue)
            Text(title).font(.title2.bold())
        }
    }

    private func diagnosticRow(title: String, detail: String, ready: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: ready ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ready ? .green : .orange).font(.title2)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }.padding(15).background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
    }

    private var musicReady: Bool {
        music.connected && !music.status.contains("거부") && !music.status.contains("실패") && !music.status.contains("먼저 실행")
    }

    private var calendarAuthorizationTitle: String {
        switch calendar.authorization {
        case .denied: return "캘린더 접근이 거부됨"
        case .restricted: return "관리 정책으로 제한됨"
        case .writeOnly: return "전체 접근이 필요함"
        default: return "캘린더 권한이 필요함"
        }
    }
}
