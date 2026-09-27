import Foundation

/// Calls `action` on every whole multiple of `interval` seconds of wall-clock time,
/// so a clock that shows seconds changes on the second and a minute countdown on the
/// minute. Re-create it after the system clock changes to re-align.
@MainActor
final class AlignedTicker {
    private var timer: Timer?

    init(interval: TimeInterval, tolerance: TimeInterval, action: @escaping @MainActor () -> Void) {
        let now = Date().timeIntervalSinceReferenceDate
        let first = Date(timeIntervalSinceReferenceDate: ((now / interval).rounded(.down) + 1) * interval)
        let timer = Timer(fire: first, interval: interval, repeats: true) { _ in
            MainActor.assumeIsolated { action() }
        }
        timer.tolerance = tolerance
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
