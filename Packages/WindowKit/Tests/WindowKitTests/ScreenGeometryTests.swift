import AppKit
import Testing

@testable import WindowKit

@Suite struct ScreenGeometryTests {
    static let primary = CGRect(x: 0, y: 0, width: 1_440, height: 900)
    static let above = CGRect(x: 0, y: 900, width: 1_920, height: 1_080)

    static let retina = CGRect(x: 0, y: 0, width: 1_512, height: 982)

    static let side = [
        ScreenGeometry.Screen(
            frame: primary, visibleFrame: CGRect(x: 0, y: 0, width: 1_440, height: 875)),
        ScreenGeometry.Screen(
            frame: CGRect(x: 1_440, y: -180, width: 1_920, height: 1_080),
            visibleFrame: CGRect(x: 1_440, y: -180, width: 1_920, height: 1_080)),
        ScreenGeometry.Screen(
            frame: CGRect(x: -1_080, y: -500, width: 1_080, height: 1_920),
            visibleFrame: CGRect(x: -1_080, y: -500, width: 1_080, height: 1_920)),
    ]

    @Test func convertsSideBySideScreens() {
        expectConversions([
            (Self.retina, Self.retina),
            (
                CGRect(x: 1_512, y: 0, width: 1_920, height: 1_080),
                CGRect(x: 1_512, y: -98, width: 1_920, height: 1_080)
            ),
            (
                CGRect(x: -1_920, y: -98, width: 1_920, height: 1_080),
                CGRect(x: -1_920, y: 0, width: 1_920, height: 1_080)
            ),
            (
                CGRect(x: 1_600, y: 200, width: 800, height: 600),
                CGRect(x: 1_600, y: 182, width: 800, height: 600)
            ),
        ])
    }

    @Test func convertsAPortraitScreen() {
        expectConversions([
            (
                CGRect(x: -1_080, y: -400, width: 1_080, height: 1_920),
                CGRect(x: -1_080, y: -538, width: 1_080, height: 1_920)
            ),
            (
                CGRect(x: -1_000, y: 1_100, width: 900, height: 400),
                CGRect(x: -1_000, y: -518, width: 900, height: 400)
            ),
        ])
    }

    @Test func convertsScreensAboveAndBelow() {
        expectConversions([
            (
                CGRect(x: -204, y: 982, width: 1_920, height: 1_080),
                CGRect(x: -204, y: -1_080, width: 1_920, height: 1_080)
            ),
            (
                CGRect(x: 0, y: -1_080, width: 1_920, height: 1_080),
                CGRect(x: 0, y: 982, width: 1_920, height: 1_080)
            ),
            (
                CGRect(x: 100, y: 1_200, width: 800, height: 600),
                CGRect(x: 100, y: -818, width: 800, height: 600)
            ),
            (
                CGRect(x: 100, y: -900, width: 800, height: 600),
                CGRect(x: 100, y: 1_282, width: 800, height: 600)
            ),
        ])
    }

    @MainActor
    @Test func matchesTheBoundsOfConnectedDisplays() throws {
        let screens = NSScreen.screens
        let primaryFrame = try #require(screens.first).frame
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        for screen in screens {
            let display = try #require(screen.deviceDescription[key] as? CGDirectDisplayID)
            #expect(
                ScreenGeometry.quartzRect(fromAppKit: screen.frame, primary: primaryFrame)
                    == CGDisplayBounds(display))
        }
    }

    private func expectConversions(
        _ pairs: [(appKit: CGRect, quartz: CGRect)],
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        for pair in pairs {
            #expect(
                ScreenGeometry.quartzRect(fromAppKit: pair.appKit, primary: Self.retina)
                    == pair.quartz, sourceLocation: sourceLocation)
            #expect(
                ScreenGeometry.appKitRect(fromQuartz: pair.quartz, primary: Self.retina)
                    == pair.appKit, sourceLocation: sourceLocation)
        }
    }

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

    @Test func movesToTheNextDisplayKeepingRelativeSize() {
        let leftHalf = CGRect(x: 0, y: 25, width: 720, height: 875)
        #expect(
            ScreenGeometry.quartzFrame(leftHalf, movedBy: 1, across: Self.side)
                == CGRect(x: 1_440, y: 0, width: 960, height: 1_080))
        #expect(
            ScreenGeometry.quartzFrame(leftHalf, movedBy: -1, across: Self.side)
                == CGRect(x: -1_080, y: -520, width: 540, height: 1_920))
        let centred = CGRect(x: 1_920, y: 270, width: 960, height: 540)
        #expect(
            ScreenGeometry.quartzFrame(centred, movedBy: 1, across: Self.side)
                == CGRect(x: -810, y: -40, width: 540, height: 960))
        #expect(
            ScreenGeometry.quartzFrame(centred, movedBy: -1, across: Self.side)
                == CGRect(x: 360, y: 243, width: 720, height: 438))
    }

    @Test func ordersStackedDisplaysTopFirst() {
        let screens = [Self.primary, Self.above, CGRect(x: 1_440, y: 0, width: 1_440, height: 900)]
            .map { ScreenGeometry.Screen(frame: $0, visibleFrame: $0) }
        let window = CGRect(x: 0, y: 0, width: 720, height: 450)
        #expect(
            ScreenGeometry.quartzFrame(window, movedBy: 1, across: screens)
                == CGRect(x: 1_440, y: 0, width: 720, height: 450))
        #expect(
            ScreenGeometry.quartzFrame(window, movedBy: -1, across: screens)
                == CGRect(x: 0, y: -1_080, width: 960, height: 540))
        #expect(
            ScreenGeometry.quartzFrame(window, movedBy: 2, across: screens)
                == CGRect(x: 0, y: -1_080, width: 960, height: 540))
    }

    @Test func staysPutWithOneDisplayOrOffscreen() {
        let window = CGRect(x: 0, y: 25, width: 720, height: 875)
        #expect(ScreenGeometry.quartzFrame(window, movedBy: 1, across: [Self.side[0]]) == nil)
        #expect(ScreenGeometry.quartzFrame(window, movedBy: 3, across: Self.side) == nil)
        #expect(ScreenGeometry.quartzFrame(window, movedBy: 1, across: []) == nil)
        let offscreen = CGRect(x: 9_000, y: 0, width: 800, height: 400)
        #expect(ScreenGeometry.quartzFrame(offscreen, movedBy: 1, across: Self.side) == nil)
    }

    @Test func centersOnTheVisibleFrame() {
        let size = CGSize(width: 760, height: 476)
        let tall = CGRect(x: 0, y: 0, width: 1_440, height: 876)
        let short = CGRect(x: 0, y: 0, width: 800, height: 480)
        let offset = CGRect(x: 1_440, y: -180, width: 1_920, height: 1_080)
        #expect(
            ScreenGeometry.centeredFrame(of: size, in: tall)
                == CGRect(x: 340, y: 200, width: 760, height: 476))
        #expect(
            ScreenGeometry.centeredFrame(of: size, in: short)
                == CGRect(x: 20, y: 2, width: 760, height: 476))
        #expect(
            ScreenGeometry.centeredFrame(of: size, in: offset)
                == CGRect(x: 2_020, y: 122, width: 760, height: 476))
    }

    @Test func shrinksToFitAVisibleFrameSmallerThanThePanel() {
        let size = CGSize(width: 760, height: 476)
        let narrow = CGRect(x: 80, y: 0, width: 700, height: 876)
        let low = CGRect(x: 0, y: 60, width: 1_440, height: 400)
        #expect(
            ScreenGeometry.centeredFrame(of: size, in: narrow)
                == CGRect(x: 80, y: 200, width: 700, height: 476))
        #expect(
            ScreenGeometry.centeredFrame(of: size, in: low)
                == CGRect(x: 340, y: 60, width: 760, height: 400))
    }

    @Test func bottomFrameDropsOverTheDockThenShrinksToClearTheTop() {
        let size = CGSize(width: 920, height: 640)
        let screen = ScreenGeometry.Screen(
            frame: CGRect(x: 0, y: 0, width: 1_440, height: 900),
            visibleFrame: CGRect(x: 0, y: 70, width: 1_440, height: 806))
        #expect(
            ScreenGeometry.bottomFrame(of: size, centeredOn: 720, below: 760, on: screen)
                == CGRect(x: 260, y: 70, width: 920, height: 640))
        #expect(
            ScreenGeometry.bottomFrame(of: size, centeredOn: 720, below: 680, on: screen)
                == CGRect(x: 260, y: 40, width: 920, height: 640))
        #expect(
            ScreenGeometry.bottomFrame(of: size, centeredOn: 720, below: 500, on: screen)
                == CGRect(x: 260, y: 0, width: 920, height: 500))
    }

    @Test func bottomFrameStaysInsideANarrowScreen() {
        let size = CGSize(width: 920, height: 640)
        let narrow = ScreenGeometry.Screen(
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            visibleFrame: CGRect(x: 0, y: 0, width: 800, height: 575))
        let wide = ScreenGeometry.Screen(
            frame: CGRect(x: 0, y: 0, width: 1_440, height: 900),
            visibleFrame: CGRect(x: 0, y: 70, width: 1_440, height: 806))
        #expect(
            ScreenGeometry.bottomFrame(of: size, centeredOn: 400, below: 400, on: narrow)
                == CGRect(x: 0, y: 0, width: 800, height: 400))
        #expect(
            ScreenGeometry.bottomFrame(of: size, centeredOn: 300, below: 760, on: wide)
                == CGRect(x: 0, y: 70, width: 920, height: 640))
        #expect(
            ScreenGeometry.bottomFrame(of: size, centeredOn: 1_300, below: 760, on: wide)
                == CGRect(x: 520, y: 70, width: 920, height: 640))
    }
}
