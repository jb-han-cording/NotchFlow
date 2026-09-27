import Foundation
/// Atomic, versioned JSON storage. Decode failures never overwrite the original file.
public final class LocalStore<Value: Codable> {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load(default fallback: @autoclosure () -> Value) throws -> Value {
        guard FileManager.default.fileExists(atPath: url.path) else { return fallback() }
        return try JSONDecoder().decode(Value.self, from: Data(contentsOf: url))
    }
    public func save(_ value: Value) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: [.atomic])
    }
    /// Make a byte-for-byte copy once before this release first changes a store.
    /// Copies remain outside the app bundle, alongside the persistent data.
    public func backupIfNeeded(forVersion version: String) throws {
        let manager = FileManager.default
        guard manager.fileExists(atPath: url.path) else { return }
        let safeVersion = version.map { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" ? String($0) : "_" }.joined()
        let backup = url.appendingPathExtension("before-\(safeVersion).bak")
        guard !manager.fileExists(atPath: backup.path) else { return }
        try manager.copyItem(at: url, to: backup)
    }
}
