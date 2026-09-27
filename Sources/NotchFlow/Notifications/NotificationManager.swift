import Combine
import Foundation
#if SWIFT_PACKAGE
import NotchFlowCore
#endif

@MainActor final class NotificationManager: ObservableObject {
    @Published private(set) var current: NotchNotification?
    private var queue = NotificationQueue()
    private var dismissTask: Task<Void, Never>?
    var onPresentation: ((Bool) -> Void)?
    
    func post(_ item: NotchNotification) {
        queue.enqueue(item)
        advanceIfIdle()
    }
    
    func dismissCurrent() {
        dismissTask?.cancel()
        current = nil
        onPresentation?(false)
        advanceIfIdle()
    }
    
    private func advanceIfIdle() {
        guard current == nil, let next = queue.dequeue() else { return }
        current = next
        onPresentation?(true)
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(next.duration))
            guard !Task.isCancelled, let self else { return }
            self.current = nil
            self.onPresentation?(false)
            self.advanceIfIdle()
        }
    }
    
    func stop() {
        dismissTask?.cancel()
    }
}
