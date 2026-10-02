import ApplicationServices
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
        let window = CGRect(x: 100, y: 100, width: 800, height: 600)

        #expect(frame(.maximize, of: CGRect(x: -5_000, y: 0, width: 800, height: 600)) == nil)
        #expect(WindowPlacement.quartzFrame(for: .maximize, of: window, across: [], gap: 0) == nil)
    }

    @Test func keepsTheGapAroundTheTarget() {
        let window = CGRect(x: 100, y: 100, width: 800, height: 600)

        #expect(
            WindowPlacement.quartzFrame(for: .maximize, of: window, across: Self.screens, gap: 8)
                == CGRect(x: 8, y: 33, width: 1_424, height: 859))
    }

    @Test func repeatingAHalfStepsThroughThirdsAndBack() {
        let window = AXUIElementCreateApplication(1)
        let frame = CGRect(x: 0, y: 25, width: 720, height: 875)
        var last: WindowPlacement.Placed?
        var applied: [LayoutEngine.Action] = []
        for _ in 0..<4 {
            let action = WindowPlacement.action(for: .leftHalf, of: window, at: frame, after: last)
            applied.append(action)
            last = .init(window: window, frame: frame, requested: .leftHalf, applied: action)
        }

        #expect(applied == [.leftHalf, .leftThird, .leftTwoThirds, .leftHalf])
    }

    @Test func startsOverUnlessTheSameKeyLastPlacedThisWindowWhereItIs() {
        let window = AXUIElementCreateApplication(1)
        let frame = CGRect(x: 0, y: 25, width: 720, height: 875)
        let last = WindowPlacement.Placed(
            window: window, frame: frame, requested: .topHalf, applied: .topThird)

        func action(
            _ requested: LayoutEngine.Action, of target: AXUIElement = window,
            at here: CGRect = frame
        ) -> LayoutEngine.Action {
            WindowPlacement.action(for: requested, of: target, at: here, after: last)
        }

        #expect(action(.topHalf) == .topTwoThirds)
        #expect(action(.bottomHalf) == .bottomHalf)
        #expect(action(.topHalf, of: AXUIElementCreateApplication(2)) == .topHalf)
        #expect(action(.topHalf, at: frame.offsetBy(dx: 10, dy: 0)) == .topHalf)
        #expect(
            WindowPlacement.action(for: .topHalf, of: window, at: frame, after: nil) == .topHalf)
    }

    @Test func leavesLayoutsWithoutSizesAsTheyAre() {
        let window = AXUIElementCreateApplication(1)
        let frame = CGRect(x: 0, y: 25, width: 480, height: 875)
        let last = WindowPlacement.Placed(
            window: window, frame: frame, requested: .leftThird, applied: .leftThird)

        #expect(
            WindowPlacement.action(for: .leftThird, of: window, at: frame, after: last)
                == .leftThird)
    }
}
