import AppKit
import Quartz
@MainActor final class QuickLookService: NSObject, @preconcurrency QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookService()
    private var item: NSURL?
    func show(_ url: URL) {
        item = url as NSURL
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self; panel.delegate = self; panel.reloadData(); panel.makeKeyAndOrderFront(nil)
    }
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { item == nil ? 0 : 1 }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! { item }
    func close() { QLPreviewPanel.shared()?.orderOut(nil); item = nil }
}
