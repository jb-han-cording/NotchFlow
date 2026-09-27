import AppKit
#if SWIFT_PACKAGE
import NotchFlowCore
#endif

@MainActor protocol ScreenProviding { func selectedScreen(id: String) -> NSScreen? }
@MainActor final class ScreenService: ScreenProviding {
    func selectedScreen(id: String) -> NSScreen? {
        NSScreen.screens.first(where: { Self.id($0) == id }) ?? NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens.first
    }
    static func id(_ screen: NSScreen) -> String { String(describing: screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] ?? "") }
    func geometry(for screen: NSScreen) -> NotchGeometry {
        let reportedTopInset = screen.safeAreaInsets.top
        let topInset = (reportedTopInset > 0 && reportedTopInset <= 96) ? reportedTopInset : 0
        let reportedMenuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        let menuBarHeight = (reportedMenuBarHeight >= 24 && reportedMenuBarHeight <= 96) ? reportedMenuBarHeight : 24
        return NotchGeometry(screen: screen.frame, topInset: topInset, leftArea: screen.auxiliaryTopLeftArea, rightArea: screen.auxiliaryTopRightArea, menuBarHeight: menuBarHeight)
    }
}
