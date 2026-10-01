import CoreGraphics
import Testing

@testable import WindowKit

@Suite struct ScreenGeometryTests {
    static let primary = CGRect(x: 0, y: 0, width: 1_440, height: 900)
    static let above = CGRect(x: 0, y: 900, width: 1_920, height: 1_080)

    @Test func picksTheScreenShowingMostOfAQuartzRect() {
        let frames = [Self.primary, Self.above]
        let onPrimary = CGRect(x: 100, y: 100, width: 800, height: 400)
        let onAbove = CGRect(x: 100, y: -500, width: 800, height: 400)
        let straddling = CGRect(x: 100, y: -100, width: 800, height: 400)
        #expect(ScreenGeometry.screenIndex(showing: onPrimary, in: frames) == 0)
        #expect(ScreenGeometry.screenIndex(showing: onAbove, in: frames) == 1)
        #expect(ScreenGeometry.screenIndex(showing: straddling, in: frames) == 0)
    }

    @Test func offscreenRectsAndNoScreensPickNothing() {
        let offscreen = CGRect(x: 5_000, y: 0, width: 800, height: 400)
        #expect(ScreenGeometry.screenIndex(showing: offscreen, in: [Self.primary]) == nil)
        #expect(ScreenGeometry.screenIndex(showing: .zero, in: [Self.primary]) == nil)
        #expect(ScreenGeometry.screenIndex(showing: offscreen, in: []) == nil)
    }

    @Test func centersInTheUpperThirdAndStaysOnScreen() {
        let size = CGSize(width: 760, height: 476)
        let tall = CGRect(x: 0, y: 0, width: 1_440, height: 876)
        let short = CGRect(x: 0, y: 0, width: 800, height: 480)
        let offset = CGRect(x: 1_440, y: -180, width: 1_920, height: 1_080)
        let narrow = CGRect(x: 80, y: 0, width: 700, height: 876)
        #expect(ScreenGeometry.upperThirdOrigin(of: size, in: tall) == CGPoint(x: 340, y: 346))
        #expect(ScreenGeometry.upperThirdOrigin(of: size, in: short) == CGPoint(x: 20, y: 4))
        #expect(ScreenGeometry.upperThirdOrigin(of: size, in: offset) == CGPoint(x: 2_020, y: 302))
        #expect(ScreenGeometry.upperThirdOrigin(of: size, in: narrow) == CGPoint(x: 80, y: 346))
    }
}
