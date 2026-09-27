import Foundation

public enum NotchState: String, Codable { case collapsed, hover, expanded, dragActive, notification }
public enum NotchEvent { case hover, exitHover, open, close, dragEnter, dragExit, drop, notify, endNotification }

public struct NotchStateMachine {
    public private(set) var state: NotchState = .collapsed
    private var beforeDrag: NotchState = .collapsed
    private var beforeNotification: NotchState = .collapsed
    public init() {}
    public mutating func send(_ event: NotchEvent) {
        switch event {
        case .hover:
            if state == .collapsed { state = .hover }
        case .exitHover:
            if state == .hover { state = .collapsed }
        case .open:
            state = .expanded
        case .close:
            state = .collapsed
        case .dragEnter:
            if state != .dragActive { beforeDrag = state; state = .dragActive }
        case .dragExit:
            if state == .dragActive { state = beforeDrag == .notification ? .collapsed : beforeDrag }
        case .drop:
            state = .expanded
        case .notify:
            if state == .collapsed || state == .hover { beforeNotification = state; state = .notification }
        case .endNotification:
            if state == .notification { state = beforeNotification == .hover ? .collapsed : beforeNotification }
        }
    }
}
