import AppKit
import Testing

@testable import GlassUI

struct LyricsBarSpotTests {
    private static let screen = LyricsBarSpot.Screen(
        frame: NSRect(x: 0, y: 0, width: 1_800, height: 1_169),
        visibleFrame: NSRect(x: 0, y: 78, width: 1_800, height: 1_052), notchEdge: 790)
    private static let dock = NSRect(x: 279, y: 10, width: 1_242, height: 72)
    private static let status = NSRect(x: 1_238, y: 1_130, width: 143, height: 39)

    private func spot(
        _ pin: LyricsPin, dock: NSRect? = dock, menusEnd: CGFloat? = 612,
        statusItems: [NSRect] = [status], on screen: LyricsBarSpot.Screen = screen
    ) -> NSRect? {
        LyricsBarSpot.frame(
            for: pin,
            around: LyricsSurroundings(
                dock: dock, menusEnd: menusEnd, statusItems: statusItems),
            on: screen)
    }

    @Test func theDockTypeStartsInTheRoomierSideAtTheIconsHeight() throws {
        let right = try #require(spot(.dock, dock: NSRect(x: 100, y: 10, width: 1_200, height: 72)))
        #expect(right == NSRect(x: 1_316, y: 14, width: 380, height: 64))
        let left = try #require(spot(.dock, dock: NSRect(x: 600, y: 10, width: 1_100, height: 72)))
        #expect(left == NSRect(x: 16, y: 14, width: 380, height: 64))
    }

    @Test func theDockTypeShrinksToTheGapAndTakesTheRightOnATie() throws {
        let frame = try #require(spot(.dock))
        #expect(frame == NSRect(x: 1_537, y: 14, width: 247, height: 64))
    }

    @Test func noDockTypeWithoutRoomOrABottomDock() {
        #expect(spot(.dock, dock: NSRect(x: 100, y: 10, width: 1_600, height: 72)) == nil)
        #expect(spot(.dock, dock: nil) == nil)
        let hidden = LyricsBarSpot.Screen(frame: Self.screen.frame, visibleFrame: Self.screen.frame)
        #expect(spot(.dock, on: hidden) == nil)
        let side = LyricsBarSpot.Screen(
            frame: Self.screen.frame, visibleFrame: NSRect(x: 80, y: 0, width: 1_720, height: 1_130)
        )
        #expect(spot(.dock, on: side) == nil)
    }

    @Test func theMenusBarFollowsTheLastMenuAndStopsAtTheNotch() throws {
        let frame = try #require(spot(.menus))
        #expect(frame == NSRect(x: 628, y: 1_139, width: 146, height: 22))
    }

    @Test func withoutANotchTheMenusBarStopsAtTheFirstStatusItem() throws {
        let flat = LyricsBarSpot.Screen(
            frame: Self.screen.frame, visibleFrame: Self.screen.visibleFrame)
        let frame = try #require(spot(.menus, on: flat))
        #expect(frame == NSRect(x: 628, y: 1_139, width: 300, height: 22))
        let near = try #require(spot(.menus, menusEnd: 1_000, on: flat))
        #expect(near.maxX == 1_222)
    }

    @Test func statusWindowsThatAreNotMenuBarItemsDoNotLimitIt() throws {
        let overlay = NSRect(x: 0, y: 0, width: 1_800, height: 1_169)
        let flat = LyricsBarSpot.Screen(
            frame: Self.screen.frame, visibleFrame: Self.screen.visibleFrame)
        let frame = try #require(spot(.menus, statusItems: [overlay], on: flat))
        #expect(frame.width == 300)
    }

    @Test func noMenusBarWithoutRoomOrAMenuBar() {
        #expect(spot(.menus, menusEnd: 700) == nil)
        #expect(spot(.menus, menusEnd: nil) == nil)
        let hidden = LyricsBarSpot.Screen(frame: Self.screen.frame, visibleFrame: Self.screen.frame)
        #expect(spot(.menus, on: hidden) == nil)
    }

    @Test func otherPinsHaveNoBar() {
        for pin in [LyricsPin.corner, .desktop, .island, .menuBar] {
            #expect(spot(pin) == nil)
        }
    }
}
