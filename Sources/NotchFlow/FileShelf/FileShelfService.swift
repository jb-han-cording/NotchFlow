import Foundation
#if SWIFT_PACKAGE
import NotchFlowCore
#endif
protocol FileShelfProviding {
    func bookmark(for url: URL) throws -> Data
    func resolve(_ item: ShelfItem) throws -> (url: URL, stale: Bool)
}
final class FileShelfService: FileShelfProviding {
    func bookmark(for url: URL) throws -> Data { try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: nil, relativeTo: nil) }
    func resolve(_ item: ShelfItem) throws -> (url: URL, stale: Bool) {
        var stale = false
        let url = try URL(resolvingBookmarkData: item.bookmark, options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
        return (url, stale)
    }
}
