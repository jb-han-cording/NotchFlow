import Foundation
import CoreGraphics

public struct NotchGeometry: Equatable {
    public var screen: CGRect
    public var cutout: CGRect
    public var hasNotch: Bool

    public init(screen: CGRect, topInset: CGFloat, leftArea: CGRect?, rightArea: CGRect?, menuBarHeight: CGFloat = 24) {
        self.screen = screen
        // NSScreen can briefly report the visible-frame delta in screen
        // coordinates while the display configuration is changing. Never let
        // that transient value turn the collapsed notch into a full-screen
        // window. Current macOS menu bars and notches are well below this cap.
        let normalizedTopInset = min(max(topInset, 0), 96)
        let normalizedMenuBarHeight = min(max(menuBarHeight, 24), 96)
        if normalizedTopInset > 0, let leftArea, let rightArea, rightArea.minX > leftArea.maxX {
            hasNotch = true
            cutout = CGRect(x: leftArea.maxX, y: screen.maxY - normalizedTopInset, width: rightArea.minX - leftArea.maxX, height: normalizedTopInset)
        } else {
            hasNotch = false
            cutout = CGRect(x: screen.midX - 78, y: screen.maxY - normalizedMenuBarHeight, width: 156, height: normalizedMenuBarHeight)
        }
    }

    /// The closed island matches the physical notch cutout exactly when music is stopped.
    public func collapsedFrame(musicPlaying: Bool) -> CGRect {
        if hasNotch {
            let extraWidth: CGFloat = musicPlaying ? 88 : 0
            return frame(width: cutout.width + extraWidth, height: cutout.height)
        } else {
            let extraWidth: CGFloat = musicPlaying ? 88 : 0
            return frame(width: 160 + extraWidth, height: max(28, cutout.height))
        }
    }

    public func frame(width: CGFloat, height: CGFloat) -> CGRect {
        let w = min(width, screen.width - 16)
        let h = min(height, screen.height - 16)
        return CGRect(x: min(max(cutout.midX - w / 2, screen.minX + 8), screen.maxX - w - 8), y: screen.maxY - h, width: w, height: h)
    }
}
