import AppKit
import SwiftUI
import Combine

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let app = AppState()
    var controller: NotchWindowController?
    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow?
    var onboardingWindow: NSWindow?
    private var subscriptions: Set<AnyCancellable> = []
    let shortcut = GlobalShortcutService()
    let updater = UpdateManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ensureSingleInstance() else { return }
        NSApp.setActivationPolicy(.accessory)
        AppLog.app.info("App Started")
        controller = NotchWindowController(app: app)
        
        // Restore music provider & auto-connect services if enabled
        if let provider = MusicProvider(rawValue: app.settings.value.musicProvider) {
            app.music.provider = provider
        }
        if app.settings.value.musicEnabled && app.settings.value.hasCompletedOnboarding {
            app.music.connect()
        }
        if app.settings.value.calendarEnabled {
            app.calendar.enabled = true
            app.calendar.refresh()
        }
        
        app.music.$track
            .map { $0?.isPlaying == true }
            .removeDuplicates()
            .sink { [weak self] playing in
                guard let self else { return }
                self.app.notch.setMusicPlaying(
                    playing && self.app.settings.value.musicEnabled,
                    collapseAfter: self.app.settings.value.animationSpeed
                )
            }.store(in: &subscriptions)

        Publishers.CombineLatest3(app.notch.$state, app.timer.$active, app.timer.$running)
            .sink { [weak self] _, _, _ in self?.updateStatusItem() }
            .store(in: &subscriptions)
        app.timer.$remaining
            .map { Int($0) }
            .removeDuplicates()
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &subscriptions)
        app.music.$track
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &subscriptions)

        app.showSettings = { [weak self] in self?.openSettings() }
        app.showOnboarding = { [weak self] in self?.openOnboarding() }
        shortcut.onPressed = { [weak self] in guard let self else { return }; self.app.notch.send(self.app.notch.state == .expanded ? .close : .open) }
        app.shortcutError = shortcut.register(app.settings.value.shortcut)
        app.settings.onChange = { [weak self] settings in
            guard let self else { return }
            
            if let provider = MusicProvider(rawValue: settings.musicProvider), self.app.music.provider != provider {
                self.app.music.provider = provider
                if settings.musicEnabled { self.app.music.connect() }
            }
            if settings.musicEnabled {
                if !self.app.music.connected { self.app.music.connect() }
            } else {
                self.app.music.disconnect()
            }
            self.app.calendar.enabled = settings.calendarEnabled
            if settings.calendarEnabled { self.app.calendar.refresh() }
            self.app.shortcutError = self.shortcut.register(settings.shortcut)
            self.setStatusItemVisible(settings.showMenuBarIcon)
        }
        setStatusItemVisible(app.settings.value.showMenuBarIcon)

        if app.settings.value.automaticUpdateChecks {
            Task { await updater.check(silent: true) }
        }
        if !app.settings.value.hasCompletedOnboarding {
            DispatchQueue.main.async { [weak self] in self?.openOnboarding() }
        }
    }

    private func ensureSingleInstance() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return true }
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let peers = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != currentPID && !$0.isTerminated }
        guard let existing = peers.first else { return true }
        existing.activate()
        NSApp.terminate(nil)
        return false
    }
    func applicationWillTerminate(_ notification: Notification) { shortcut.stop(); app.stop() }

    private func setStatusItemVisible(_ visible: Bool) {
        if !visible {
            if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
            statusItem = nil
            return
        }
        guard statusItem == nil else {
            updateStatusItem()
            return
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu
        updateStatusItem()
        rebuildStatusMenu(menu)
    }

    private func menuItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildStatusMenu(menu)
    }

    private func rebuildStatusMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        let isOpen = app.notch.state == .expanded || app.notch.state == .hover
        menu.addItem(menuItem(isOpen ? "NotchFlow 접기" : "NotchFlow 펼치기", action: #selector(toggleNotch)))

        let modules = NSMenu(title: "바로 열기")
        for module in Module.allCases where app.isEnabled(module) {
            let item = menuItem(moduleMenuTitle(module), action: #selector(openModule(_:)))
            item.representedObject = module.rawValue
            item.image = NSImage(systemSymbolName: module.icon, accessibilityDescription: nil)
            modules.addItem(item)
        }
        let modulesItem = NSMenuItem(title: "바로 열기", action: nil, keyEquivalent: "")
        modulesItem.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: nil)
        modulesItem.submenu = modules
        menu.addItem(modulesItem)

        if app.music.connected {
            menu.addItem(.separator())
            if let track = app.music.track {
                let nowPlaying = NSMenuItem(title: "\(track.title) · \(track.artist)", action: nil, keyEquivalent: "")
                nowPlaying.isEnabled = false
                nowPlaying.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
                menu.addItem(nowPlaying)
            }
            let controls = NSMenu(title: "음악 제어")
            controls.addItem(menuItem("이전 곡", action: #selector(previousTrack)))
            controls.addItem(menuItem(app.music.track?.isPlaying == true ? "일시정지" : "재생", action: #selector(togglePlayback)))
            controls.addItem(menuItem("다음 곡", action: #selector(nextTrack)))
            let controlsItem = NSMenuItem(title: "음악 제어", action: nil, keyEquivalent: "")
            controlsItem.image = NSImage(systemSymbolName: "play.circle", accessibilityDescription: nil)
            controlsItem.submenu = controls
            menu.addItem(controlsItem)
        }

        let timerMenu = NSMenu(title: "타이머")
        if app.timer.active {
            let status = NSMenuItem(title: "남은 시간  \(app.timer.text)", action: nil, keyEquivalent: "")
            status.isEnabled = false
            timerMenu.addItem(status)
            timerMenu.addItem(menuItem(app.timer.running ? "일시정지" : "계속", action: #selector(toggleTimer)))
            timerMenu.addItem(menuItem("초기화", action: #selector(resetTimer)))
            timerMenu.addItem(.separator())
        }
        for minutes in [5, 25, 50] {
            let item = menuItem("\(minutes)분 시작", action: #selector(startTimer(_:)))
            item.representedObject = minutes
            timerMenu.addItem(item)
        }
        let timerItem = NSMenuItem(title: app.timer.active ? "타이머 · \(app.timer.text)" : "타이머", action: nil, keyEquivalent: "")
        timerItem.image = NSImage(systemSymbolName: "timer", accessibilityDescription: nil)
        timerItem.submenu = timerMenu
        menu.addItem(timerItem)

        menu.addItem(.separator())
        let settingsItem = menuItem("설정…", action: #selector(showSettingsMenu), key: ",")
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settingsItem)
        menu.addItem(menuItem("NotchFlow 종료", action: #selector(quitApp), key: "q"))
    }

    private func moduleMenuTitle(_ module: Module) -> String {
        switch module {
        case .dashboard: return "대시보드"
        case .music: return "음악"
        case .calendar: return "캘린더"
        case .shelf: return "파일 선반"
        case .memo: return "메모"
        case .timer: return "타이머"
        }
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        let symbol: String
        if app.timer.active { symbol = app.timer.running ? "timer" : "pause.circle" }
        else if app.music.track?.isPlaying == true { symbol = "waveform" }
        else { symbol = "macwindow.on.rectangle" }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "NotchFlow")
        image?.isTemplate = true
        button.image = image
        button.toolTip = app.timer.active ? "NotchFlow · 타이머 \(app.timer.text)" : "NotchFlow"
    }

    @objc private func toggleNotch() {
        let isOpen = app.notch.state == .expanded || app.notch.state == .hover
        app.notch.send(isOpen ? .close : .open)
    }
    @objc private func openModule(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String, let module = Module(rawValue: rawValue) else { return }
        app.selectedModule = module
        app.notch.send(.open)
    }
    @objc private func previousTrack() { app.music.refresh(command: .previous) }
    @objc private func togglePlayback() { app.music.refresh(command: .playPause) }
    @objc private func nextTrack() { app.music.refresh(command: .next) }
    @objc private func startTimer(_ sender: NSMenuItem) {
        guard let minutes = sender.representedObject as? Int else { return }
        app.timer.reset()
        app.timer.configure(minutes: minutes)
        app.timer.start()
    }
    @objc private func toggleTimer() { app.timer.running ? app.timer.pause() : app.timer.start() }
    @objc private func resetTimer() { app.timer.reset() }
    @objc private func showSettingsMenu() { openSettings() }
    @objc private func quitApp() { NSApp.terminate(nil) }

    private func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = SettingsView(
            model: app.settings,
            music: app.music,
            calendar: app.calendar,
            updater: updater,
            shortcutError: app.shortcutError,
            showOnboarding: { [weak self] in self?.openOnboarding() }
        )
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 560), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.center()
        window.title = "NotchFlow 설정"
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openOnboarding() {
        if let window = onboardingWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = OnboardingView(music: app.music, calendar: app.calendar) { [weak self] in
            guard let self else { return }
            self.app.settings.value.hasCompletedOnboarding = true
            if self.app.settings.value.musicEnabled && !self.app.music.connected { self.app.music.connect() }
            if self.app.settings.value.calendarEnabled { self.app.calendar.refresh() }
            self.onboardingWindow?.orderOut(nil)
            self.onboardingWindow = nil
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "NotchFlow 시작하기"
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false
        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
