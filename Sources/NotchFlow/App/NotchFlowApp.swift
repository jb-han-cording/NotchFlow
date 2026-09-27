import SwiftUI
@main struct NotchFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        Settings {
            SettingsView(
                model: delegate.app.settings,
                music: delegate.app.music,
                calendar: delegate.app.calendar,
                updater: delegate.updater,
                shortcutError: delegate.app.shortcutError,
                showOnboarding: { delegate.app.showOnboarding?() }
            )
        }
    }
}
