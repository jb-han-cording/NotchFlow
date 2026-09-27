import SwiftUI

struct DashboardView: View {
    @ObservedObject var app: AppState
    @ObservedObject var music: MusicViewModel
    @ObservedObject var calendar: CalendarViewModel
    @ObservedObject var shelf: FileShelfViewModel
    @ObservedObject var memo: MemoViewModel

    var body: some View {
        HStack(spacing: 10) {
            if app.isEnabled(.music) {
                card(.music, title: music.track?.title ?? "재생 없음", subtitle: music.track?.artist ?? "음악 상태", color: .notchBlue)
            }
            if app.isEnabled(.calendar) {
                card(.calendar, title: calendar.next?.title ?? "일정 없음", subtitle: calendar.next.map { $0.start.formatted(date: .omitted, time: .shortened) } ?? "오늘 일정", color: .orange)
            }
            if app.isEnabled(.shelf) {
                card(.shelf, title: shelf.items.isEmpty ? "파일 놓기" : "\(shelf.items.count)개 파일", subtitle: shelf.items.first?.name ?? "Drag & Drop", color: .cyan)
            }
            if app.isEnabled(.memo) {
                card(.memo, title: memo.recent.first?.title ?? "빠른 메모", subtitle: memo.memos.isEmpty ? "생각을 기록하세요" : "\(memo.memos.count)개의 메모", color: .yellow)
            }
            if !Module.allCases.contains(where: { $0 != .dashboard && app.isEnabled($0) }) {
                Text("설정에서 사용할 기능을 켜세요.").foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 122)
            }
        }
    }

    private func card(_ module: Module, title: String, subtitle: String, color: Color) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                app.selectedModule = module
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    if module == .music, let track = music.track {
                        AlbumArtworkView(track: track, size: 30)
                    } else {
                        Image(systemName: module.icon).font(.system(size: 17, weight: .medium))
                            .foregroundStyle(color).frame(width: 30, height: 30)
                    }
                    Spacer(minLength: 0)
                    Text(module.rawValue.uppercased()).font(.system(size: 8, weight: .semibold)).tracking(0.6).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .background(color.opacity(0.065), in: RoundedRectangle(cornerRadius: 17))
            .contentShape(RoundedRectangle(cornerRadius: 17))
        }
        .buttonStyle(.plain)
        .help("\(module.rawValue) · \(title)")
    }
}
