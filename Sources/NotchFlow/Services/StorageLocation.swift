import Foundation

enum StorageLocation {
    static func file(_ name: String) -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("NotchFlow", isDirectory: true).appendingPathComponent(name)
    }
}
