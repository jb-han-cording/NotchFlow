import AppKit
import SwiftUI
#if SWIFT_PACKAGE
import NotchFlowCore
#endif

struct FileShelfView: View {
    @ObservedObject var model: FileShelfViewModel
    @State private var confirmClear = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    Text("파일을 잠시 모아두세요")
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Button("새로 고침") { model.refresh() }
                        .font(.system(size: 12, weight: .medium))
                    Button("모두 비우기") { confirmClear = true }
                        .font(.system(size: 12, weight: .medium))
                        .disabled(model.items.isEmpty || !model.writable)
                }
                if model.items.isEmpty { ContentUnavailableView("Drop to Shelf", systemImage: "tray.and.arrow.down", description: Text("파일과 폴더를 이곳에 놓으세요.\n원본은 이동하거나 복사하지 않습니다.")) }
                ForEach(model.items) { item in
                    HStack(spacing: 12) {
                        Image(nsImage: model.urls[item.id].map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSImage(systemSymbolName: "questionmark.folder", accessibilityDescription: nil)!).resizable().frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name).lineLimit(1)
                            Text(model.urls[item.id] == nil ? "Missing · 파일을 다시 추가하세요" : "원본 위치 유지").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let url = model.urls[item.id] {
                            Button { QuickLookService.shared.show(url) } label: { Image(systemName: "eye") }.buttonStyle(NotchIconButtonStyle()).help("Quick Look").accessibilityLabel("Quick Look")
                            Button { NSWorkspace.shared.activateFileViewerSelecting([url]) } label: { Image(systemName: "folder") }.buttonStyle(NotchIconButtonStyle()).help("Finder에서 보기").accessibilityLabel("Finder에서 보기")
                            Button {
                                NSSharingService(named: .sendViaAirDrop)?.perform(withItems: [url])
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .buttonStyle(NotchIconButtonStyle())
                            .help("AirDrop으로 보내기")
                            .accessibilityLabel("AirDrop으로 보내기")
                        }
                        Button { model.remove(item) } label: { Image(systemName: "xmark") }.buttonStyle(NotchIconButtonStyle()).help("선반에서 제거").accessibilityLabel("선반에서 제거").disabled(!model.writable)
                    }.padding(12).background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
                    .onDrag { model.urls[item.id].map { NSItemProvider(object: $0 as NSURL) } ?? NSItemProvider() }
                }
                if let error = model.error { Text(error).font(.caption).foregroundStyle(.orange) }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { model.refresh() }
        .confirmationDialog("선반의 모든 참조를 제거할까요? 원본 파일은 유지됩니다.", isPresented: $confirmClear) { Button("선반 비우기", role: .destructive) { model.clear() } }
    }
}
