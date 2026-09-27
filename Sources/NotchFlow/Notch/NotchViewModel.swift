import SwiftUI
#if SWIFT_PACKAGE
import NotchFlowCore
#endif

@MainActor final class NotchViewModel: ObservableObject {
    @Published private(set) var musicPlaying = false
    @Published private(set) var musicIslandVisible = false
    @Published private(set) var state: NotchState = .collapsed
    @Published var geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1440, height: 900), topInset: 0, leftArea: nil, rightArea: nil)
    private var machine = NotchStateMachine()
    private var hoverTask: Task<Void, Never>?
    private var musicIslandHideTask: Task<Void, Never>?
    private var pointerInside = false
    var onChange: (() -> Void)?
    var isMouseInsidePanel: (() -> Bool)?

    func setMusicPlaying(_ playing: Bool, collapseAfter: Double = 0.32) {
        musicIslandHideTask?.cancel()
        musicIslandHideTask = nil
        if playing {
            // Prepare the side graphics while they are still clipped by the
            // physical notch, then reveal them as the panel grows outward.
            musicIslandVisible = true
            guard !musicPlaying else { return }
            musicPlaying = true
            onChange?()
        } else {
            guard musicPlaying || musicIslandVisible else { return }
            musicPlaying = false
            onChange?()
            // Keep the last artwork/equalizer alive until the shrinking panel
            // has clipped them back into the physical notch.
            musicIslandHideTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(max(0.1, collapseAfter)))
                guard !Task.isCancelled, let self, !self.musicPlaying else { return }
                self.musicIslandVisible = false
            }
        }
    }

    func send(_ event: NotchEvent) {
        if case .close = event {
            hoverTask?.cancel()
            hoverTask = nil
            pointerInside = false
        }
        machine.send(event)
        guard state != machine.state else { return }
        hoverTask?.cancel()
        hoverTask = nil
        state = machine.state
        AppLog.app.info("Notch state: \(self.state.rawValue, privacy: .public)")
        onChange?()
    }

    func activateHeader() {
        send(state == .expanded ? .close : .open)
    }

    func hover(_ inside: Bool, enabled: Bool, delay: Double) {
        guard enabled else {
            pointerInside = false
            hoverTask?.cancel()
            hoverTask = nil
            if state == .hover { send(.exitHover) }
            return
        }

        if !inside && state == .hover {
            if let check = isMouseInsidePanel, check() {
                // Mouse is physically inside panel frame. Ignore fake exit.
                return
            }
        }

        guard pointerInside != inside else { return }
        pointerInside = inside
        hoverTask?.cancel()
        hoverTask = nil

        guard (inside && state == .collapsed) || (!inside && state == .hover) else { return }

        let wait = inside ? delay : 0.16
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            guard let self else { return }

            if !inside && self.state == .hover {
                if let check = self.isMouseInsidePanel, check() {
                    self.pointerInside = true
                    return
                }
            }

            guard self.pointerInside == inside else { return }
            self.send(inside ? .hover : .exitHover)
        }
    }

    func stop() {
        hoverTask?.cancel(); hoverTask = nil
        musicIslandHideTask?.cancel(); musicIslandHideTask = nil
    }
}
