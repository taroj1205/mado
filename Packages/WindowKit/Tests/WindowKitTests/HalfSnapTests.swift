import CoreGraphics
import Testing

@testable import WindowKit

@Suite struct HalfSnapTests {
    static let gap: CGFloat = 12
    static let leftHalf = CGRect(x: 12, y: 78, width: 702, height: 786)
    static let rightHalf = CGRect(x: 726, y: 78, width: 702, height: 786)

    static func remaining(_ frame: CGRect, beside other: CGRect, _ side: HalfSnap.Side) -> CGRect {
        HalfSnap.remaining(of: frame, beside: other, on: side, gap: gap)
    }

    @Test func rightHalfStartsOneGapAfterAWiderLeftWindow() {
        let left = CGRect(x: 12, y: 78, width: 900, height: 786)
        #expect(
            Self.remaining(Self.rightHalf, beside: left, .right)
                == CGRect(x: 924, y: 78, width: 504, height: 786))
    }

    @Test func leftHalfEndsOneGapBeforeAWiderRightWindow() {
        let right = CGRect(x: 528, y: 78, width: 900, height: 786)
        #expect(
            Self.remaining(Self.leftHalf, beside: right, .left)
                == CGRect(x: 12, y: 78, width: 504, height: 786))
    }

    @Test func keepsTheHalfWhenTheOtherWindowDoesNotOverlapIt() {
        let otherScreen = CGRect(x: -1_428, y: 78, width: 900, height: 786)
        let below = CGRect(x: 12, y: 900, width: 900, height: 400)
        #expect(
            Self.remaining(Self.rightHalf, beside: otherScreen, .right) == Self.rightHalf)
        #expect(Self.remaining(Self.rightHalf, beside: below, .right) == Self.rightHalf)
    }

    @Test func targetNarrowsOnlyBesideAWindowOnTheOtherSide() {
        let wideLeft = HalfSnap.Blocker(
            side: .left, frame: CGRect(x: 12, y: 78, width: 900, height: 786))

        #expect(
            HalfSnap.target(Self.rightHalf, on: .right, beside: [wideLeft], gap: Self.gap)
                == CGRect(x: 924, y: 78, width: 504, height: 786))
        #expect(
            HalfSnap.target(Self.leftHalf, on: .left, beside: [wideLeft], gap: Self.gap)
                == Self.leftHalf)
        #expect(
            HalfSnap.target(Self.rightHalf, on: .right, beside: [], gap: Self.gap) == Self.rightHalf
        )
    }

    @Test func keepsTheHalfWhenNoWidthIsLeft() {
        let wide = CGRect(x: 12, y: 78, width: 1_416, height: 786)
        #expect(Self.remaining(Self.rightHalf, beside: wide, .right) == Self.rightHalf)
        #expect(Self.remaining(Self.leftHalf, beside: wide, .left) == Self.leftHalf)
    }
}
