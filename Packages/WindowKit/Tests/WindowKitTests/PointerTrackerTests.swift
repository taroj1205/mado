import AppKit
import Testing

@testable import WindowKit

@MainActor
@Suite struct PointerTrackerTests {
    final class Moves {
        var count = 0
    }

    static func spin(seconds: TimeInterval, until done: () -> Bool) {
        let deadline = Date(timeIntervalSinceNow: seconds)
        while !done(), Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }
    }

    @Test(.enabled(if: !NSScreen.screens.isEmpty, "Display links need a screen"))
    func readsThePointerEveryFrameOnlyWhileTracking() {
        let moves = Moves()
        let tracker = PointerTracker { _ in moves.count += 1 }
        #expect(!tracker.isTracking)

        tracker.start()
        tracker.start()
        #expect(tracker.isTracking)
        #expect(moves.count == 1)
        Self.spin(seconds: 1) { moves.count > 3 }
        #expect(moves.count > 3)

        tracker.stop()
        #expect(!tracker.isTracking)
        let stopped = moves.count
        Self.spin(seconds: 0.2) { moves.count > stopped }
        #expect(moves.count == stopped)
    }
}
