import CoreGraphics
import Testing

@testable import WindowKit

@Suite struct WindowMoverTests {
    static let before = CGRect(x: 100, y: 100, width: 800, height: 600)
    static let snapped = CGRect(x: 0, y: 25, width: 720, height: 875)
    static let quarter = CGRect(x: 0, y: 25, width: 720, height: 437)
    static let first = WindowMover.Placement(restore: before, placed: snapped)

    @Test func remembersTheFrameBeforeTheFirstSnap() {
        #expect(
            WindowMover.placement(after: nil, from: Self.before, to: Self.snapped) == Self.first)
    }

    @Test func keepsThePreSnapFrameAcrossSnaps() {
        let next = WindowMover.placement(after: Self.first, from: Self.snapped, to: Self.quarter)
        #expect(next == WindowMover.Placement(restore: Self.before, placed: Self.quarter))
    }

    @Test func forgetsItWhenTheWindowWasMovedSince() {
        let dragged = CGRect(x: 300, y: 200, width: 720, height: 875)
        let next = WindowMover.placement(after: Self.first, from: dragged, to: Self.quarter)
        #expect(next == WindowMover.Placement(restore: dragged, placed: Self.quarter))
    }

    @Test func remembersNothingWhenTheWindowRefusedToMove() {
        let fullScreen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        #expect(WindowMover.placement(after: nil, from: fullScreen, to: fullScreen) == nil)
        #expect(
            WindowMover.placement(after: Self.first, from: Self.snapped, to: Self.snapped)
                == Self.first)
    }
}
