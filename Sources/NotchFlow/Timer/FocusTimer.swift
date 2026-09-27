import SwiftUI

@MainActor final class FocusTimer: ObservableObject {
    @Published private(set) var remaining: TimeInterval = 1500
    @Published private(set) var running = false
    @Published private(set) var active = false
    private(set) var duration: TimeInterval = 1500
    private var deadline: Date?
    private var ticker: Timer?
    var onComplete: (() -> Void)?
    var text: String {
        let seconds = Int(ceil(remaining))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    func configure(minutes: Int) {
        guard !active else { return }
        duration = Double(min(180, max(1, minutes))) * 60
        remaining = duration
    }
    func start(now: Date = Date(), schedule: Bool = true) {
        guard !running else { return }
        if remaining <= 0 { remaining = duration }
        deadline = now.addingTimeInterval(remaining)
        running = true
        active = true
        if schedule {
            let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
            timer.tolerance = 0.1
            ticker = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    func tick(now: Date = Date()) {
        guard running, let deadline else { return }
        remaining = max(0, deadline.timeIntervalSince(now))
        if remaining == 0 {
            stopTicker()
            active = false
            onComplete?()
        }
    }
    func pause(now: Date = Date()) {
        tick(now: now)
        stopTicker()
    }
    func reset() {
        stopTicker()
        active = false
        remaining = duration
    }
    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
        deadline = nil
        running = false
    }
}

struct FocusTimerView: View {
    @ObservedObject var timer: FocusTimer
    @State private var minutes = 25
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "timer").foregroundStyle(.notchBlue).font(.title)
                Text(timer.text).font(.system(size: 34, weight: .medium, design: .rounded)).monospacedDigit()
                Spacer()
                Button(timer.running ? "일시정지" : timer.active ? "계속" : "시작") {
                    if timer.running { timer.pause() } else { timer.start() }
                }
                Button("초기화") { timer.reset() }
            }
            HStack(spacing: 8) {
                ForEach([5, 25, 50], id: \.self) { value in
                    Button("\(value)분") { minutes = value; timer.configure(minutes: value) }
                }
                Spacer(minLength: 0)
                TextField("분", value: $minutes, format: .number)
                    .textFieldStyle(.roundedBorder).frame(width: 48)
                    .onChange(of: minutes) { _, value in timer.configure(minutes: value) }
                Text("분").foregroundStyle(.secondary)
            }.disabled(timer.active)
            ProgressView(value: timer.remaining, total: timer.duration).tint(.notchBlue)
        }
    }
}

struct CompactTimerView: View {
    @ObservedObject var timer: FocusTimer
    let cutoutWidth: CGFloat
    var body: some View {
        ZStack {
            Image(systemName: timer.running ? "timer" : "pause.fill")
                .foregroundStyle(.notchBlue).offset(x: -cutoutWidth / 2 - 25)
            Text(timer.text).font(.system(size: 10, weight: .semibold)).monospacedDigit()
                .foregroundStyle(.white).offset(x: cutoutWidth / 2 + 26)
        }
    }
}
