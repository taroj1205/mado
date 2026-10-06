import AppKit
import Testing

@testable import GlassUI

@MainActor
struct WipeLinesTests {
    private static let key = "sweep"
    private let wipes = WipeLines()

    private func sweep(_ index: Int) -> CABasicAnimation? {
        wipes.strips[index].animation(forKey: Self.key) as? CABasicAnimation
    }

    private func scale(_ index: Int) -> Double {
        (wipes.strips[index].value(forKeyPath: "transform.scale.x") as? Double) ?? 0
    }

    private func fit(_ widths: [CGFloat]) {
        let rows = widths.enumerated().map { row in
            CGRect(x: 0, y: CGFloat(row.offset) * 24, width: row.element, height: 24)
        }
        wipes.fit(rows)
    }

    @Test func oneLineSweepsTheWholeRemainingTimeLikeAPlainWipe() throws {
        fit([200])
        wipes.run(from: 0.25, remaining: 6, playing: true, restart: true)
        let animation = try #require(sweep(0))
        #expect(animation.duration == 6)
        #expect(animation.fromValue as? Double == 0.25)
        #expect(animation.beginTime == 0)
    }

    @Test func earlierLinesFinishFirstAndLaterOnesWaitForThem() throws {
        fit([100, 100])
        wipes.run(from: 0.25, remaining: 6, playing: true, restart: true)
        let first = try #require(sweep(0))
        let second = try #require(sweep(1))
        #expect(first.duration == 2)
        #expect(first.fromValue as? Double == 0.5)
        #expect(second.duration == 4)
        #expect(second.beginTime > 0)
        #expect(second.fillMode == .backwards)
    }

    @Test func linesThatAreAlreadySungStayLitAndLaterOnesStayDarkWhilePaused() {
        fit([100, 100, 100])
        wipes.run(from: 0.5, remaining: nil, playing: false, restart: true)
        #expect(sweep(0) == nil)
        #expect(scale(0) == 1)
        #expect(abs(scale(1) - 0.5) < 0.001)
        #expect(scale(2) < 0.01)
    }

    @Test func refittingKeepsTheSweepGoingOnTheNewLines() {
        fit([200])
        wipes.run(from: 0, remaining: 4, playing: true, restart: true)
        fit([100, 100])
        #expect(wipes.strips.count == 2)
        #expect(sweep(0) != nil)
        #expect(sweep(1) != nil)
        fit([200])
        #expect(wipes.strips.count == 1)
    }

    @Test func forgettingTheSweepStopsARefitFromStartingNewOnes() {
        fit([200])
        wipes.run(from: 0, remaining: 4, playing: true, restart: true)
        wipes.forget()
        fit([100, 100])
        #expect(wipes.strips.count == 2)
        #expect(sweep(1) == nil)
    }
}
