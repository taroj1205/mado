import CoreGraphics
import Testing

@testable import WindowKit

@Suite struct WindowPlacementTests {
    static let screens = [
        ScreenGeometry.Screen(
            frame: CGRect(x: 0, y: 0, width: 1_440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_440, height: 875)),
        ScreenGeometry.Screen(
            frame: CGRect(x: 1_440, y: 0, width: 1_920, height: 1_080),
            visibleFrame: CGRect(x: 1_440, y: 0, width: 1_920, height: 1_080)),
    ]

    private func frame(_ action: LayoutEngine.Action, of window: CGRect) -> CGRect? {
        WindowPlacement.quartzFrame(for: action, of: window, across: Self.screens, gap: 0)
    }

    @Test func placesTheWindowOnTheScreenItIsOnInQuartzCoordinates() {
        let primary = CGRect(x: 100, y: 100, width: 800, height: 600)
        let secondary = CGRect(x: 1_600, y: 100, width: 800, height: 600)

        #expect(frame(.topHalf, of: primary) == CGRect(x: 0, y: 25, width: 1_440, height: 437.5))
        #expect(
            frame(.leftHalf, of: secondary) == CGRect(x: 1_440, y: -180, width: 960, height: 1_080))
        #expect(
            frame(.centre, of: secondary) == CGRect(x: 2_000, y: 60, width: 800, height: 600))
    }

    @Test func leavesAWindowOffEveryScreenAlone() {
        #expect(frame(.maximize, of: CGRect(x: -5_000, y: 0, width: 800, height: 600)) == nil)
    }
}
