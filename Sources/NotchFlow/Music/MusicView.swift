import SwiftUI

struct MusicView: View {
    @ObservedObject var model: MusicViewModel
    @ObservedObject var settings: SettingsViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if !model.connected {
                    HStack(spacing: 14) {
                        Picker("플레이어", selection: Binding(
                            get: { model.provider },
                            set: { (provider: MusicProvider) in
                                model.provider = provider
                                settings.value.musicProvider = provider.rawValue
                                model.connect()
                            }
                        )) {
                            ForEach(MusicProvider.allCases) { Text($0.rawValue).tag($0) }
                        }.pickerStyle(.segmented).frame(maxWidth: 230)
                        Spacer(minLength: 0)
                        Button("연결") {
                            model.connect()
                        }.font(.system(size: 12, weight: .medium)).disabled(model.busy)
                    }
                }
                if let track = model.track {
                    HStack(spacing: 16) {
                        AlbumArtworkView(track: track, size: 70)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(track.title).font(.system(size: 16, weight: .bold)).lineLimit(1)
                                    Text(track.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer(minLength: 8)
                                HStack(spacing: 8) {
                                    control("backward.end.fill", "이전 곡", .previous)
                                    control(track.isPlaying ? "pause.fill" : "play.fill", "재생 / 일시 정지", .playPause)
                                    control("forward.end.fill", "다음 곡", .next)
                                }.font(.title3).disabled(model.busy)
                            }
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                HStack(spacing: 10) {
                                    Text(time(track.progress(at: context.date)))
                                    ProgressView(value: track.progress(at: context.date), total: max(1, track.duration)).tint(.notchBlue)
                                    Text(time(track.duration))
                                }.font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 14) {
                        AlbumArtworkView(track: nil, size: 52)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("음악을 가까이").font(.system(size: 16, weight: .bold))
                            Text(model.connected ? "재생 중인 곡이 없습니다." : "플레이어를 선택하고 연결하세요.").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                if !model.status.isEmpty {
                    Text(model.status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func control(_ symbol: String, _ label: String, _ command: MusicCommand) -> some View {
        Button { model.refresh(command: command) } label: { Image(systemName: symbol) }
            .buttonStyle(NotchIconButtonStyle()).accessibilityLabel(label)
    }
    private func time(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.isFinite ? seconds : 0))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
