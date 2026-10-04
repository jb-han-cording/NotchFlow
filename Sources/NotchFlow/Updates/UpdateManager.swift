import Combine
import Foundation
import Sparkle

@MainActor final class UpdateManager: ObservableObject {
    let controller: SPUStandardUpdaterController
    @Published private(set) var status = "업데이트를 확인하지 않았습니다."
    @Published private(set) var checking = false

    init() {
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    var isConfigured: Bool { controller.updater.feedURL != nil }

    func setAutomaticChecks(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
        status = enabled ? "자동 업데이트 확인이 켜져 있습니다." : "자동 업데이트 확인이 꺼져 있습니다."
    }

    func check(silent: Bool = false) async {
        guard isConfigured else {
            if !silent { status = "Sparkle 업데이트 appcast 주소가 설정되지 않았습니다." }
            return
        }
        guard controller.updater.canCheckForUpdates else {
            if !silent { status = "지금은 업데이트를 확인할 수 없습니다." }
            return
        }
        checking = true
        status = "업데이트를 확인하고 있습니다…"
        if silent {
            controller.updater.checkForUpdatesInBackground()
        } else {
            controller.updater.checkForUpdates()
        }
        checking = false
    }
}
