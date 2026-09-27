import SwiftUI

extension ShapeStyle where Self == Color {
    static var notchBlue: Color { Color(red: 0.38, green: 0.57, blue: 0.88) }
}

/// Keep the visual glyph small enough for a compact panel, with a larger hit area.
struct NotchIconButtonStyle: ButtonStyle {
    var selected = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .frame(width: 44, height: 44)
            .contentShape(RoundedRectangle(cornerRadius: 11))
            .background(Color.primary.opacity(configuration.isPressed ? 0.16 : selected ? 0.11 : 0.045), in: RoundedRectangle(cornerRadius: 11))
            .opacity(enabled ? 1 : 0.4)
    }
}

struct NotchActionButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .contentShape(RoundedRectangle(cornerRadius: 11))
            .background((prominent ? Color.notchBlue : Color.primary).opacity(configuration.isPressed ? 0.24 : prominent ? 0.16 : 0.075), in: RoundedRectangle(cornerRadius: 11))
            .opacity(enabled ? 1 : 0.4)
    }
}
