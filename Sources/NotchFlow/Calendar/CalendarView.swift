import SwiftUI

struct CalendarView: View {
    @ObservedObject var model: CalendarViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    Text(Date(), format: .dateTime.month(.wide).day())
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Button("캘린더 열기") { model.openCalendar() }
                        .font(.system(size: 12, weight: .medium))
                }
                if model.authorized {
                    if let next = model.next {
                        HStack {
                            Label("다음 일정", systemImage: "clock")
                            Spacer()
                            if next.start <= Date() { Text("진행 중") }
                            else { Text(next.start, style: .relative); Text("후") }
                        }.font(.caption).foregroundStyle(.notchBlue)
                    }
                    if model.events.isEmpty {
                        Text("오늘 예정된 일정이 없습니다.").font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 4)
                    } else {
                        ForEach(model.events) { event in
                            HStack(alignment: .top, spacing: 12) {
                                RoundedRectangle(cornerRadius: 2).fill(.notchBlue).frame(width: 3)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(event.title).font(.headline)
                                    if event.isAllDay { Text("하루 종일").foregroundStyle(.secondary) }
                                    else { Text(event.start, format: .dateTime.hour().minute()).foregroundStyle(.secondary) }
                                }
                                Spacer()
                            }.fixedSize(horizontal: false, vertical: true).padding(.vertical, 2)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("캘린더를 연결하면 오늘의 일정을 볼 수 있습니다.").font(.caption).foregroundStyle(.secondary)
                        if model.requesting {
                            HStack(spacing: 10) {
                                ProgressView().controlSize(.small)
                                Text("macOS 권한 확인 중…").font(.subheadline)
                            }.accessibilityElement(children: .combine)
                        }
                        if model.authorization == .denied {
                            Button("시스템 설정에서 허용") { model.openPermissionSettings() }
                                .buttonStyle(NotchActionButtonStyle(prominent: true))
                        } else if model.authorization != .restricted {
                            Button(model.requesting ? "권한 확인 중…" : model.authorization == .writeOnly ? "전체 접근 요청" : "캘린더 접근 허용") {
                                NSApp.activate(ignoringOtherApps: true)
                                Task { await model.connect() }
                            }.buttonStyle(NotchActionButtonStyle(prominent: true)).disabled(model.requesting)
                        }
                    }
                }
                if !model.status.isEmpty {
                    Text(model.status).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .buttonStyle(NotchActionButtonStyle())
        .task { model.refresh() }
    }
}
