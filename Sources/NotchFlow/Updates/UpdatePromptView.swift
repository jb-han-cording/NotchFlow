import SwiftUI

struct UpdatePromptView: View {
    @ObservedObject var updater: UpdateManager
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.tint)
                Text("새로운 NotchFlow 업데이트")
                    .font(.title2.weight(.semibold))
                if let manifest = updater.available {
                    Text("버전 \(manifest.version) (build \(manifest.build))을 사용할 수 있습니다.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 26)
            .padding(.bottom, 20)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("릴리즈 노트")
                    .font(.headline)
                ScrollView {
                    Text(updater.available?.releaseNotes?.isEmpty == false ? updater.available?.releaseNotes ?? "" : "이번 업데이트의 릴리즈 노트가 없습니다.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 135)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)

            Divider()

            VStack(spacing: 10) {
                if updater.downloading {
                    ProgressView("다운로드 중…")
                        .frame(maxWidth: .infinity)
                } else {
                    HStack {
                        Button("나중에") { onClose() }
                            .keyboardShortcut(.cancelAction)
                        Spacer()
                        Button("다운로드") {
                            Task { await updater.downloadAndOpen() }
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                    }
                }
                if updater.status.contains("실패") {
                    Text(updater.status)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
        }
        .frame(width: 500, height: 390)
    }
}
