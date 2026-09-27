import SwiftUI

struct AlbumArtworkView: View {
    var track: MusicTrack?
    var size: CGFloat
    var body: some View {
        Group {
            if let artwork = track?.artwork {
                Image(nsImage: artwork).resizable().scaledToFill()
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.notchBlue)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LinearGradient(colors: [.notchBlue.opacity(0.25), .cyan.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24))
        .accessibilityHidden(true)
    }
}

struct AudioEqualizerView: View {
    var isPlaying: Bool
    var style: String = "Blue"
    var barCount: Int = 6
    var maxHeight: CGFloat = 16
    var isVisible: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let barRates: [Double] = [0.38, 0.24, 0.46, 0.30, 0.42, 0.26, 0.36]
    private let barAmplitudes: [CGFloat] = [0.92, 0.55, 1.00, 0.68, 0.88, 0.62, 0.95]

    private func barGradient(for index: Int, total: Int) -> AnyShapeStyle {
        switch style {
        case "Neon Pink":
            return AnyShapeStyle(LinearGradient(colors: [.pink, .purple], startPoint: .bottom, endPoint: .top))
        case "Cyan Wave":
            return AnyShapeStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .bottom, endPoint: .top))
        case "Sunset Gradient":
            return AnyShapeStyle(LinearGradient(colors: [.orange, .pink, .purple], startPoint: .bottom, endPoint: .top))
        case "Flame Red":
            return AnyShapeStyle(LinearGradient(colors: [.yellow, .orange, .red], startPoint: .bottom, endPoint: .top))
        case "Monochrome White":
            return AnyShapeStyle(Color.white.opacity(0.9))
        case "Rainbow":
            let colors: [Color] = [.pink, .purple, .indigo, .cyan, .notchBlue, .yellow, .orange]
            return AnyShapeStyle(colors[index % colors.count])
        default: // Blue, including the legacy Mint preference.
            return AnyShapeStyle(LinearGradient(colors: [.notchBlue, .notchBlue.opacity(0.7)], startPoint: .bottom, endPoint: .top))
        }
    }

    var body: some View {
        // Derive each frame from time instead of a repeatForever transaction.
        // Window layout/visibility changes can cancel that transaction without
        // changing playback state, leaving the old implementation frozen.
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPlaying || !isVisible || reduceMotion)) { context in
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0..<barCount, id: \.self) { index in
                    let time = context.date.timeIntervalSinceReferenceDate
                    let phase = time * Double.pi / barRates[index % barRates.count] + Double(index) * 1.7
                    let wave = (sin(phase) + 1) / 2
                    let ratio = isPlaying && !reduceMotion
                        ? 0.22 + wave * Double(barAmplitudes[index % barAmplitudes.count]) * 0.68
                        : 0.22
                    Capsule()
                        .fill(barGradient(for: index, total: barCount))
                        .frame(width: 1.5, height: max(3, maxHeight * ratio))
                }
            }
            .frame(height: maxHeight)
        }
        .transaction { $0.animation = nil }
        .accessibilityHidden(true)
    }
}
