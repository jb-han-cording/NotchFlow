import Combine
import ServiceManagement
#if SWIFT_PACKAGE
import NotchFlowCore
#endif
@MainActor final class SettingsViewModel: ObservableObject {
    @Published var value: AppSettings { didSet { save() } }
    @Published var error: String?
    @Published private(set) var loginEnabled = false
    private let store: LocalStore<AppSettings>
    private var writable = true
    private var backedUp = false
    private let updateVersion: String
    var onChange: ((AppSettings) -> Void)?
    init(url: URL = StorageLocation.file("settings-v1.json"), updateVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "development") {
        store = LocalStore(url: url)
        self.updateVersion = updateVersion
        do { var loaded = try store.load(default: AppSettings()); loaded.normalize(); value = loaded }
        catch { value = AppSettings(); writable = false; self.error = "설정 파일을 읽을 수 없어 기본값을 사용합니다. 기존 파일은 보존됩니다." }
        refreshLogin()
    }
    private func save() {
        onChange?(value)
        guard writable else { return }
        do {
            if !backedUp { try store.backupIfNeeded(forVersion: updateVersion); backedUp = true }
            try store.save(value)
        } catch { self.error = "설정을 백업하거나 저장하지 못했습니다. 기존 파일은 보존됩니다." }
    }
    func refreshLogin() { loginEnabled = SMAppService.mainApp.status == .enabled }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            refreshLogin()
            if SMAppService.mainApp.status == .requiresApproval { error = "시스템 설정 → 일반 → 로그인 항목에서 NotchFlow를 허용하세요." }
        } catch { self.error = "로그인 실행을 변경하지 못했습니다. 서명된 앱을 Applications에 설치한 뒤 다시 시도하세요."; refreshLogin() }
    }
}
