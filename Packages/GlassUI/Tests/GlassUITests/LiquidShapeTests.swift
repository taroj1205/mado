import AppKit
import Testing

@testable import GlassUI

@Suite struct LiquidShapeTests {
    private static let frame = 1.0 / 60

    private static func settle(_ shape: inout LiquidShape) -> [LiquidShape] {
        var frames: [LiquidShape] = []
        for _ in 0..<120 where !shape.isSettled {
            shape.advance(by: frame)
            frames.append(shape)
        }
        return frames
    }

    private static func shown(width: CGFloat) -> LiquidShape {
        var shape = LiquidShape(height: 44)
        shape.show(width: width, animated: true)
        _ = settle(&shape)
        return shape
    }

    @Test func startsAsAnInvisibleDroplet() {
        let shape = LiquidShape(height: 44)
        #expect(shape.size == CGSize(width: 16, height: 16))
        #expect(shape.alpha == 0)
        #expect(shape.isSettled)
    }

    @Test func bloomsFromADropletWithASmallOvershoot() {
        var shape = LiquidShape(height: 44)
        shape.show(width: 200, animated: true)
        #expect(shape.size == CGSize(width: 16, height: 16))
        let frames = Self.settle(&shape)
        let widest = frames.map(\.size.width).max() ?? 0
        #expect(widest > 200)
        #expect(widest < 210)
        #expect(frames.first.map { $0.alpha > 0 && $0.alpha < 1 } == true)
        #expect(frames.first?.contentAlpha == 0)
        #expect(frames.count < 60)
        #expect(shape.size == CGSize(width: 200, height: 44))
        #expect(shape.alpha == 1)
        #expect(shape.contentAlpha == 1)
    }

    @Test func narrowingBulgesAndWideningThins() {
        var shape = Self.shown(width: 200)
        shape.show(width: 120, animated: true)
        let narrowing = Self.settle(&shape).map(\.size.height)
        #expect(narrowing.contains { $0 > 44 })
        #expect(narrowing.allSatisfy { $0 >= 44 * 0.92 && $0 <= 44 * 1.08 })
        shape.show(width: 280, animated: true)
        let widening = Self.settle(&shape).map(\.size.height)
        #expect(widening.contains { $0 < 44 })
        #expect(widening.allSatisfy { $0 >= 44 * 0.92 && $0 <= 44 * 1.08 })
        #expect(shape.size == CGSize(width: 280, height: 44))
    }

    @Test func hidingCollapsesIntoADropletAndStartsOver() {
        var shape = Self.shown(width: 200)
        shape.hide(animated: true)
        let frames = Self.settle(&shape)
        #expect(frames.contains { $0.alpha > 0 && $0.size.width < 200 })
        #expect(!shape.isShown)
        #expect(shape.size == CGSize(width: 16, height: 16))
        #expect(shape.alpha == 0)
    }

    @Test func showingAgainWhileHidingGrowsBackFromWhereItIs() {
        var shape = Self.shown(width: 200)
        shape.hide(animated: true)
        for _ in 0..<6 {
            shape.advance(by: Self.frame)
        }
        let shrunk = shape.size.width
        shape.show(width: 200, animated: true)
        shape.advance(by: Self.frame)
        #expect(abs(shape.size.width - shrunk) < 20)
        _ = Self.settle(&shape)
        #expect(shape.size == CGSize(width: 200, height: 44))
        #expect(shape.alpha == 1)
    }

    @Test func reducedMotionSnapsTheShapeAndOnlyFades() {
        var shape = LiquidShape(height: 44)
        shape.show(width: 200, animated: false)
        #expect(shape.size == CGSize(width: 200, height: 44))
        #expect(shape.alpha == 0)
        let showing = Self.settle(&shape)
        #expect(showing.allSatisfy { $0.size == CGSize(width: 200, height: 44) && $0.alpha <= 1 })
        #expect(showing.count < 20)
        shape.show(width: 120, animated: false)
        #expect(shape.size == CGSize(width: 120, height: 44))
        #expect(shape.isSettled)
        shape.hide(animated: false)
        let hiding = Self.settle(&shape)
        #expect(hiding.dropLast().allSatisfy { $0.size == CGSize(width: 120, height: 44) })
        #expect(hiding.map(\.alpha) == hiding.map(\.alpha).sorted(by: >))
        #expect(shape.alpha == 0)
    }

    @Test func aCriticallyDampedSpringNeverOvershoots() {
        var spring = Spring(0, duration: 0.2, bounce: 0, tolerance: 0.001)
        spring.target = 1
        var highest: CGFloat = 0
        for _ in 0..<60 {
            spring.advance(by: Self.frame)
            highest = max(highest, spring.value)
        }
        #expect(highest == 1)
        #expect(spring.isSettled)
    }
}
