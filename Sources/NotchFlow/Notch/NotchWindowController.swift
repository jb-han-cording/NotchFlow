import AppKit
import Combine
import QuartzCore
import SwiftUI
#if SWIFT_PACKAGE
import NotchFlowCore
#endif

final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

@MainActor final class NotchWindowController: NSObject, NSWindowDelegate {
    private var panel: NotchPanel
    private let screens: ScreenService
    private let model: NotchViewModel
    private let settings: SettingsViewModel
    private let notifications: NotificationManager
    private let app: AppState
    private var selectedScreen: String
    private var expandedWidth: CGFloat
    private var module: Module
    private var cancellables = Set<AnyCancellable>()
    private var targetFrame: CGRect = .zero
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var hoverTimer: Timer?
    private var hoverStartedAt: TimeInterval?
    private var exitStartedAt: TimeInterval?
    private var transitionEndsAt: TimeInterval = 0
    private var ignoreOutsideClicksUntil: TimeInterval = 0
    private var suppressHoverUntilMouseExit = false
    private var lastLoggedState: NotchState?
    private var resizeDisplayLink: CADisplayLink?
    private var resizeStartFrame: CGRect = .zero
    private var resizeStartedAt: CFTimeInterval = 0
    private var resizeDuration: CFTimeInterval = 0.3
    private lazy var resizeDriver = NotchResizeDriver(controller: self)

    init(app: AppState, screens: ScreenService? = nil) {
        self.app = app
        self.screens = screens ?? ScreenService()
        self.model = app.notch
        self.settings = app.settings
        self.notifications = app.notifications
        self.selectedScreen = app.settings.value.screenID
        self.expandedWidth = app.settings.value.expandedWidth
        self.module = app.selectedModule
        self.panel = NotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        self.panel.delegate = self
        setupHosting()
        bind()
        setupMonitors()
        setupHoverTimer()
        layout()
    }

    private func setupHosting() {
        let rootView = NotchView(app: app, model: model, settings: settings, notifications: notifications, music: app.music, calendar: app.calendar)
        let hostingView = FirstMouseHostingView(rootView: rootView)
        hostingView.sizingOptions = []
        hostingView.wantsLayer = true
        hostingView.autoresizingMask = [.width, .height]
        hostingView.layer?.contentsGravity = CALayerContentsGravity.top
        panel.contentView = hostingView
        panel.contentView?.wantsLayer = true
        panel.contentView?.autoresizingMask = [.width, .height]
        panel.contentView?.layer?.contentsGravity = CALayerContentsGravity.top
        panel.minSize = NSSize(width: 1, height: 1)
        panel.contentMinSize = NSSize(width: 1, height: 1)
    }

    private func setupHoverTimer() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        guard settings.value.openOnHover else { return }
        let timer = Timer(timeInterval: 0.10, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.checkHoverState()
            }
        }
        timer.tolerance = 0.025
        RunLoop.main.add(timer, forMode: .common)
        hoverTimer = timer
    }

    private func checkHoverState() {
        guard settings.value.openOnHover, panel.isVisible else {
            hoverStartedAt = nil
            exitStartedAt = nil
            return
        }

        let mouseLoc = NSEvent.mouseLocation
        let now = ProcessInfo.processInfo.systemUptime
        guard resizeDisplayLink == nil, now >= transitionEndsAt else { return }
        guard let screen = screens.selectedScreen(id: selectedScreen) else { return }
        let geometry = screens.geometry(for: screen)

        switch model.state {
        case .collapsed:
            exitStartedAt = nil
            let collapsedBox = geometry.collapsedFrame(musicPlaying: model.musicPlaying || app.timer.active)
            let expandedTriggerBox = collapsedBox.insetBy(dx: -6, dy: -6)

            if suppressHoverUntilMouseExit {
                if !expandedTriggerBox.contains(mouseLoc) {
                    suppressHoverUntilMouseExit = false
                }
                hoverStartedAt = nil
                return
            }

            if expandedTriggerBox.contains(mouseLoc) {
                if hoverStartedAt == nil { hoverStartedAt = now }
                if now - (hoverStartedAt ?? now) >= settings.value.hoverDelay {
                    hoverStartedAt = nil
                    model.send(.hover)
                }
            } else {
                hoverStartedAt = nil
            }
        case .hover:
            hoverStartedAt = nil
            let expandedPanelBox = targetFrame.union(panel.frame).insetBy(dx: -16, dy: -16)
            if expandedPanelBox.contains(mouseLoc) {
                exitStartedAt = nil
            } else {
                if exitStartedAt == nil { exitStartedAt = now }
                if now - (exitStartedAt ?? now) >= 0.24 {
                    exitStartedAt = nil
                    suppressHoverUntilMouseExit = true
                    model.send(.exitHover)
                }
            }
        case .expanded:
            hoverStartedAt = nil
            exitStartedAt = nil
        default:
            hoverStartedAt = nil
            exitStartedAt = nil
        }
    }

    private func bind() {
        var previousState = model.state
        model.$state.sink { [weak self] state in
            guard let self else { return }
            let stateChanged = state != previousState
            if state == .collapsed, previousState != .collapsed {
                self.suppressHoverUntilMouseExit = true
            } else {
                self.suppressHoverUntilMouseExit = false
            }
            previousState = state
            DispatchQueue.main.async { [weak self] in
                guard let self, self.model.state == state else { return }
                self.layout(animated: stateChanged)
                if state == .expanded { self.panel.makeKey() }
            }
            if state == .expanded {
                self.ignoreOutsideClicksUntil = ProcessInfo.processInfo.systemUptime + 0.45
            }
        }.store(in: &cancellables)

        model.$musicPlaying.removeDuplicates().sink { [weak self] _ in
            DispatchQueue.main.async { self?.layout(animated: true) }
        }.store(in: &cancellables)
        app.timer.$active.removeDuplicates().sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.app.objectWillChange.send()
                self?.layout()
            }
        }.store(in: &cancellables)
        settings.$value
            .removeDuplicates()
            .sink { [weak self] value in
                self?.selectedScreen = value.screenID
                self?.expandedWidth = value.expandedWidth
                self?.setupHoverTimer()
                self?.layout()
            }.store(in: &cancellables)
        app.$selectedModule.sink { [weak self] mod in
            self?.module = mod
            self?.layout()
        }.store(in: &cancellables)
    }

    private func isFrameApproximatelyEqual(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.origin.x - b.origin.x) < 0.5 &&
        abs(a.origin.y - b.origin.y) < 0.5 &&
        abs(a.size.width - b.size.width) < 0.5 &&
        abs(a.size.height - b.size.height) < 0.5
    }

    func layout(showIfNeeded: Bool = true, animated: Bool = false) {
        guard let screen = screens.selectedScreen(id: selectedScreen) else { panel.orderOut(nil); return }
        let geometry = screens.geometry(for: screen)
        if model.geometry != geometry { model.geometry = geometry; AppLog.app.info("Screen Detected; Notch Detected: \(geometry.hasNotch)") }
        let size: CGSize
        switch model.state {
        case .collapsed:
            size = geometry.collapsedFrame(musicPlaying: model.musicPlaying || app.timer.active).size
        case .hover, .expanded:
            let contentHeight: CGFloat = 190
            let headerHeight = max(geometry.cutout.height, 24)
            let availableHeight = max(screen.visibleFrame.height, screen.frame.height - 12, 160)
            size = CGSize(width: expandedWidth, height: min(headerHeight + contentHeight, availableHeight))
        case .notification:
            size = CGSize(width: max(400, geometry.cutout.width + 140), height: geometry.cutout.height + 68)
        case .dragActive:
            size = CGSize(width: expandedWidth, height: geometry.cutout.height + 150)
        }
        let target = geometry.frame(width: size.width, height: size.height)
        // Unrelated updates must not restart a transition already heading here.
        if (model.state == .hover || model.state == .expanded), !model.presentsExpandedContent {
            model.presentsExpandedContent = true
        }
        if resizeDisplayLink != nil, isFrameApproximatelyEqual(targetFrame, target) { return }
        targetFrame = target
        resizeDisplayLink?.invalidate()
        resizeDisplayLink = nil

        let speed = settings.value.animationSpeed
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        if !isFrameApproximatelyEqual(panel.frame, target) {
            if animated && !reduceMotion && panel.isVisible {
                resizeDuration = max(0.1, speed)
                transitionEndsAt = ProcessInfo.processInfo.systemUptime + resizeDuration
                resizeStartFrame = panel.frame
                resizeStartedAt = CACurrentMediaTime()
                let link = panel.contentView!.displayLink(target: resizeDriver, selector: #selector(NotchResizeDriver.tick(_:)))
                resizeDisplayLink = link
                link.add(to: .main, forMode: .common)
            } else {
                applyFrame(target)
                finishResize()
            }
        } else {
            finishResize()
        }

        if lastLoggedState != model.state {
            lastLoggedState = model.state
            AppLog.app.info("Panel state=\(self.model.state.rawValue, privacy: .public) target=\(NSStringFromRect(target), privacy: .private) actual=\(NSStringFromRect(self.panel.frame), privacy: .private)")
        }
        if showIfNeeded, !panel.isVisible { panel.orderFrontRegardless() }
    }

    fileprivate func advanceResize(_ link: CADisplayLink) {
        let fraction = min(1, max(0, (link.targetTimestamp - resizeStartedAt) / resizeDuration))
        let eased = fraction * fraction * (3 - 2 * fraction)
        let width = resizeStartFrame.width + (targetFrame.width - resizeStartFrame.width) * eased
        let height = resizeStartFrame.height + (targetFrame.height - resizeStartFrame.height) * eased
        // Round symmetric edges to physical pixels to avoid alternating
        // subpixel rasterization while keeping the top anchored at the notch.
        let scale = panel.backingScaleFactor
        let halfWidth = (width * scale / 2).rounded() / scale
        let pixelHeight = (height * scale).rounded() / scale
        let frame = CGRect(x: targetFrame.midX - halfWidth, y: targetFrame.maxY - pixelHeight,
                           width: halfWidth * 2, height: pixelHeight)
        if fraction >= 1 {
            applyFrame(targetFrame)
            finishResize()
        } else if !isFrameApproximatelyEqual(panel.frame, frame) {
            applyFrame(frame)
        }
    }

    private func finishResize() {
        resizeDisplayLink?.invalidate()
        resizeDisplayLink = nil
        transitionEndsAt = 0
        let expanded = model.state == .hover || model.state == .expanded
        if model.presentsExpandedContent != expanded { model.presentsExpandedContent = expanded }
    }

    private func applyFrame(_ frame: CGRect) {
        // Commit window geometry and SwiftUI layout together, without a second
        // implicit layer animation that can displace the header/equalizer.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        panel.setFrame(frame, display: false, animate: false)
        // The hosting view autoresizes with the window. Let AppKit coalesce
        // layout and drawing for this display refresh instead of forcing both.
        CATransaction.commit()
    }

    private func setupMonitors() {
        model.isMouseInsidePanel = { [weak self] in
            guard let self, self.panel.isVisible else { return false }
            return self.panel.frame.contains(NSEvent.mouseLocation)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleOutsideClick(event: event)
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleOutsideClick(event: event)
        }
    }

    private func handleOutsideClick(event: NSEvent) {
        guard model.state == .expanded || model.state == .hover else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now >= ignoreOutsideClicksUntil else { return }
        let mouseLoc = NSEvent.mouseLocation
        if !panel.frame.contains(mouseLoc) {
            model.send(.close)
        }
    }

    func showSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            if window.title == "NotchFlow 설정" || window.identifier?.rawValue == "settings" {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
    }
}

@MainActor private final class NotchResizeDriver: NSObject {
    weak var controller: NotchWindowController?

    init(controller: NotchWindowController) { self.controller = controller }

    @objc func tick(_ link: CADisplayLink) {
        guard let controller else { link.invalidate(); return }
        controller.advanceResize(link)
    }
}
