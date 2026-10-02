import CoreGraphics
import Testing

@testable import WindowKit

@Suite struct LayoutEngineTests {
    static let visibleFrame = CGRect(x: 0, y: 66, width: 1_440, height: 810)
    static let window = CGSize(width: 800, height: 600)
    static let gap: CGFloat = 12

    static let expected: [LayoutEngine.Action: (gapless: CGRect, gapped: CGRect)] = [
        .leftHalf: (
            CGRect(x: 0, y: 66, width: 720, height: 810),
            CGRect(x: 12, y: 78, width: 702, height: 786)
        ),
        .rightHalf: (
            CGRect(x: 720, y: 66, width: 720, height: 810),
            CGRect(x: 726, y: 78, width: 702, height: 786)
        ),
        .topHalf: (
            CGRect(x: 0, y: 471, width: 1_440, height: 405),
            CGRect(x: 12, y: 477, width: 1_416, height: 387)
        ),
        .bottomHalf: (
            CGRect(x: 0, y: 66, width: 1_440, height: 405),
            CGRect(x: 12, y: 78, width: 1_416, height: 387)
        ),
        .topLeftQuarter: (
            CGRect(x: 0, y: 471, width: 720, height: 405),
            CGRect(x: 12, y: 477, width: 702, height: 387)
        ),
        .topRightQuarter: (
            CGRect(x: 720, y: 471, width: 720, height: 405),
            CGRect(x: 726, y: 477, width: 702, height: 387)
        ),
        .bottomLeftQuarter: (
            CGRect(x: 0, y: 66, width: 720, height: 405),
            CGRect(x: 12, y: 78, width: 702, height: 387)
        ),
        .bottomRightQuarter: (
            CGRect(x: 720, y: 66, width: 720, height: 405),
            CGRect(x: 726, y: 78, width: 702, height: 387)
        ),
        .leftThird: (
            CGRect(x: 0, y: 66, width: 480, height: 810),
            CGRect(x: 12, y: 78, width: 464, height: 786)
        ),
        .centreThird: (
            CGRect(x: 480, y: 66, width: 480, height: 810),
            CGRect(x: 488, y: 78, width: 464, height: 786)
        ),
        .rightThird: (
            CGRect(x: 960, y: 66, width: 480, height: 810),
            CGRect(x: 964, y: 78, width: 464, height: 786)
        ),
        .leftTwoThirds: (
            CGRect(x: 0, y: 66, width: 960, height: 810),
            CGRect(x: 12, y: 78, width: 940, height: 786)
        ),
        .rightTwoThirds: (
            CGRect(x: 480, y: 66, width: 960, height: 810),
            CGRect(x: 488, y: 78, width: 940, height: 786)
        ),
        .centre: (
            CGRect(x: 320, y: 171, width: 800, height: 600),
            CGRect(x: 320, y: 171, width: 800, height: 600)
        ),
        .maximize: (
            CGRect(x: 0, y: 66, width: 1_440, height: 810),
            CGRect(x: 12, y: 78, width: 1_416, height: 786)
        ),
        .almostMaximize: (
            CGRect(x: 72, y: 106.5, width: 1_296, height: 729),
            CGRect(x: 72, y: 106.5, width: 1_296, height: 729)
        ),
    ]

    static func frame(_ action: LayoutEngine.Action, gap: CGFloat, window: CGSize) -> CGRect {
        LayoutEngine.frame(for: action, in: visibleFrame, gap: gap, windowSize: window)
    }

    @Test(arguments: LayoutEngine.Action.allCases)
    func placesEachActionWithAndWithoutGaps(action: LayoutEngine.Action) throws {
        let frames = try #require(Self.expected[action])
        #expect(Self.frame(action, gap: 0, window: Self.window) == frames.gapless)
        #expect(Self.frame(action, gap: Self.gap, window: Self.window) == frames.gapped)
    }

    @Test func centreShrinksAWindowLargerThanTheGappedArea() {
        let large = CGSize(width: 1_600, height: 1_000)
        #expect(Self.frame(.centre, gap: 0, window: large) == Self.visibleFrame)
        #expect(
            Self.frame(.centre, gap: Self.gap, window: large)
                == CGRect(x: 12, y: 78, width: 1_416, height: 786))
    }

    @Test func almostMaximizeKeepsAGapWiderThanItsMargin() {
        #expect(
            Self.frame(.almostMaximize, gap: 100, window: Self.window)
                == CGRect(x: 100, y: 166, width: 1_240, height: 610))
    }

    @Test func placesWithoutAGapThatLeavesNoRoomForTheSmallestTile() throws {
        let topHalf = try #require(Self.expected[.topHalf]).gapless
        let leftThird = try #require(Self.expected[.leftThird]).gapless
        for unfit: CGFloat in [-8, 270, 360] {
            #expect(Self.frame(.topHalf, gap: unfit, window: Self.window) == topHalf)
            #expect(Self.frame(.leftThird, gap: unfit, window: Self.window) == leftThird)
        }
        #expect(
            Self.frame(.topHalf, gap: 269, window: Self.window)
                == CGRect(x: 269, y: 605.5, width: 902, height: 1.5))
    }
}
