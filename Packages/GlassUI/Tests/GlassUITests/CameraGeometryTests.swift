import CoreGraphics
import Testing

@testable import GlassUI

@Suite struct CameraGeometryTests {
    private let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)

    @Test func readsTheShapeOfTheVideo() {
        let video = CameraGeometry.aspect(of: CGSize(width: 1_280, height: 720))
        #expect(abs(video - CameraGeometry.widescreen) < 0.0001)
        let classic = CameraGeometry.aspect(of: CGSize(width: 1_440, height: 1_080))
        #expect(abs(classic - 4.0 / 3.0) < 0.0001)
        #expect(CameraGeometry.aspect(of: .zero) == CameraGeometry.widescreen)
    }

    @Test func keepsTheWidthInRangeAndRoundsTheHeight() {
        let normal = CameraGeometry.size(width: 360, aspect: 4 / 3)
        #expect(normal == CGSize(width: 360, height: 270))
        let narrow = CameraGeometry.size(width: 40, aspect: 2)
        #expect(narrow == CGSize(width: CameraGeometry.minimumWidth, height: 110))
        let wide = CameraGeometry.size(width: 5_000, aspect: 2)
        #expect(wide == CGSize(width: CameraGeometry.maximumWidth, height: 480))
    }

    @Test func startsInTheBottomRightCornerWithNothingSaved() {
        let frame = CameraGeometry.frame(saved: nil, areas: [screen])
        #expect(frame.size == CGSize(width: 360, height: 203))
        #expect(frame.maxX == screen.maxX - 24)
        #expect(frame.minY == screen.minY + 24)
    }

    @Test func returnsToWhereTheUserLeftIt() {
        let saved = CGRect(x: 200, y: 300, width: 480, height: 270)
        #expect(CameraGeometry.frame(saved: saved, areas: [screen]) == saved)
    }

    @Test func fallsBackToTheCornerWhenTheSavedScreenIsGone() {
        let saved = CGRect(x: 3_000, y: 300, width: 480, height: 270)
        let frame = CameraGeometry.frame(saved: saved, areas: [screen])
        #expect(frame.size == saved.size)
        #expect(frame.maxX == screen.maxX - 24)
    }

    @Test func widensFromTheCornerKeepingTheShapeAndTheTopLeft() {
        let frame = CGRect(x: 100, y: 500, width: 360, height: 270)
        let wider = CameraGeometry.resized(frame, widening: 120)
        #expect(wider == CGRect(x: 100, y: 410, width: 480, height: 360))
        let tooWide = CameraGeometry.resized(frame, widening: 5_000)
        #expect(tooWide.width == CameraGeometry.maximumWidth)
        let tooNarrow = CameraGeometry.resized(frame, widening: -5_000)
        #expect(tooNarrow.width == CameraGeometry.minimumWidth)
        #expect(tooNarrow.maxY == frame.maxY)
    }

    @Test func refitKeepsTheWidthAndTheTopLeft() {
        let frame = CGRect(x: 100, y: 500, width: 360, height: 203)
        let next = CameraGeometry.refit(frame, aspect: 4 / 3, areas: [screen])
        #expect(next == CGRect(x: 100, y: 433, width: 360, height: 270))
        #expect(next.minX == frame.minX)
        #expect(next.maxY == frame.maxY)
    }

    @Test func refitSlidesUpWhenTheTallerShapeWouldLeaveTheScreen() {
        let frame = CGRect(x: 1_056, y: 24, width: 360, height: 203)
        let next = CameraGeometry.refit(frame, aspect: 4 / 3, areas: [screen])
        #expect(next == CGRect(x: 1_056, y: screen.minY, width: 360, height: 270))
    }
}
