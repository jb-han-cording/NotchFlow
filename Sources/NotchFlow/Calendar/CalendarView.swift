import SwiftUI

struct CalendarView: View {
    @ObservedObject var model: CalendarViewModel
    @State private var displayedMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()

    private var monthDays: [Date?] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let offset = (calendar.component(.weekday, from: displayedMonth) - calendar.firstWeekday + 7) % 7
        var days = Array<Date?>(repeating: nil, count: offset)
        for day in range {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: displayedMonth))
        }
        days += Array(repeating: nil, count: (7 - days.count % 7) % 7)
        return days
    }

    private var monthCalendar: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("이전 달")
                Text(displayedMonth, format: .dateTime.year().month(.wide))
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                Button("오늘") { model.selectedDate = Date(); displayedMonth = startOfMonth(for: model.selectedDate) }
                    .font(.caption)
                Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel("다음 달")
            }
            .buttonStyle(.plain)

            let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
            let firstWeekday = Calendar.current.firstWeekday
            HStack(spacing: 2) {
                ForEach(0..<7, id: \.self) { index in
                    Text(symbols[(firstWeekday - 1 + index) % 7])
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 3) {
                ForEach(monthDays.indices, id: \.self) { index in
                    if let date = monthDays[index] {
                        dayButton(date)
                    } else {
                        Color.clear.frame(height: 29)
                    }
                }
            }
        }
    }

    private func dayButton(_ date: Date) -> some View {
        let selected = Calendar.current.isDate(date, inSameDayAs: model.selectedDate)
        let today = Calendar.current.isDateInToday(date)
        return Button {
            model.selectedDate = date
        } label: {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 12, weight: selected ? .bold : .medium))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 29)
                .background(selected ? Color.notchBlue : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(today && !selected ? Color.notchBlue : Color.clear, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
    }

    private func startOfMonth(for date: Date) -> Date {
        Calendar.current.dateInterval(of: .month, for: date)?.start ?? date
    }

    private func moveMonth(_ count: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: count, to: displayedMonth) {
            displayedMonth = startOfMonth(for: next)
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    Text("캘린더")
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Button("캘린더 열기") { model.openCalendar() }
                        .font(.system(size: 12, weight: .medium))
                }
                if model.authorized {
                    monthCalendar
                    Divider()
                    HStack {
                        Text(model.selectedDate, format: .dateTime.month().day().weekday(.wide))
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text("\(model.selectedEvents.count)개 일정")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if Calendar.current.isDateInToday(model.selectedDate), let next = model.next {
                        HStack {
                            Label("다음 일정", systemImage: "clock")
                            Spacer()
                            if next.start <= Date() { Text("진행 중") }
                            else { Text(next.start, style: .relative); Text("후") }
                        }.font(.caption).foregroundStyle(.notchBlue)
                    }
                    if let meeting = model.selectedEvents.first(where: { $0.end > Date() && $0.meetingURL != nil }), let url = meeting.meetingURL {
                        HStack {
                            Label(meeting.title, systemImage: "video").lineLimit(1)
                            Spacer()
                            Link("회의 참가", destination: url).help(url.host ?? "회의 열기")
                        }
                    }
                    if model.selectedEvents.isEmpty {
                        Text("선택한 날짜에 예정된 일정이 없습니다.").font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 4)
                    } else {
                        ForEach(model.selectedEvents) { event in
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
        .onAppear { displayedMonth = startOfMonth(for: model.selectedDate) }
        .onChange(of: model.selectedDate) { _, date in displayedMonth = startOfMonth(for: date) }
    }
}
