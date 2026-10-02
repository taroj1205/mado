import CoreGraphics
import Testing

@testable import WindowKit

@Suite struct WindowMoverTests {
    static let before = CGRect(x: 100, y: 100, width: 800, height: 600)
    static let snapped = CGRect(x: 0, y: 25, width: 720, height: 875)

    @Test func remembersTheFrameBeforeTheFirstSnap() {
        #expect(WindowMover.restoreFrame(keeping: nil, current: Self.before) == Self.before)
    }

    @Test func keepsThePreSnapFrameAcrossSnaps() {
        let placement = WindowMover.Placement(restore: Self.before, placed: Self.snapped)
        #expect(WindowMover.restoreFrame(keeping: placement, current: Self.snapped) == Self.before)
    }

    @Test func forgetsItWhenTheWindowWasMovedSince() {
        let placement = WindowMover.Placement(restore: Self.before, placed: Self.snapped)
        let dragged = CGRect(x: 300, y: 200, width: 720, height: 875)
        #expect(WindowMover.restoreFrame(keeping: placement, current: dragged) == dragged)
    }
}
