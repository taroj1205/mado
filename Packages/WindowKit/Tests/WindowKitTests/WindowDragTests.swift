import CoreGraphics
import Testing

@testable import WindowKit

@Suite struct WindowDragTests {
    static let window = CGRect(x: 100, y: 100, width: 400, height: 300)

    @Test func moveKeepsTheSizeAndFollowsThePointer() {
        let drag = WindowDrag(.move, window: Self.window, pointer: CGPoint(x: 150, y: 120))
        #expect(
            drag.frame(pointer: CGPoint(x: 180, y: 70))
                == CGRect(x: 130, y: 50, width: 400, height: 300))
    }

    @Test func resizeMovesTheCornerNearestThePointerAndKeepsTheOpposite() {
        let maxCorner = WindowDrag(.resize, window: Self.window, pointer: CGPoint(x: 480, y: 390))
        #expect(
            maxCorner.frame(pointer: CGPoint(x: 520, y: 410))
                == CGRect(x: 100, y: 100, width: 440, height: 320))

        let minCorner = WindowDrag(.resize, window: Self.window, pointer: CGPoint(x: 120, y: 110))
        #expect(
            minCorner.frame(pointer: CGPoint(x: 90, y: 150))
                == CGRect(x: 70, y: 140, width: 430, height: 260))
    }

    @Test func resizeMixesEdgesForTheOtherCorners() {
        let drag = WindowDrag(.resize, window: Self.window, pointer: CGPoint(x: 120, y: 390))
        #expect(
            drag.frame(pointer: CGPoint(x: 140, y: 420))
                == CGRect(x: 120, y: 100, width: 380, height: 330))
    }

    @Test func resizeStopsAtTheMinimumInsteadOfFlipping() {
        let drag = WindowDrag(.resize, window: Self.window, pointer: CGPoint(x: 480, y: 390))
        let side = WindowDrag.minimumSide
        #expect(
            drag.frame(pointer: CGPoint(x: -1_000, y: -1_000))
                == CGRect(x: 100, y: 100, width: side, height: side))
    }

    @Test func aWindowSmallerThanTheMinimumDoesNotJumpWhenTheResizeStarts() {
        let small = CGRect(x: 0, y: 0, width: 50, height: 40)
        let drag = WindowDrag(.resize, window: small, pointer: CGPoint(x: 45, y: 35))
        #expect(drag.frame(pointer: CGPoint(x: 45, y: 35)) == small)
        #expect(drag.frame(pointer: .zero) == small)
    }
}
