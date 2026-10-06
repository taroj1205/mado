import AppKit
import Testing

@testable import GlassUI

struct LyricsGeometryTests {
    private static let screens = [
        NSRect(x: 0, y: 0, width: 1_440, height: 875),
        NSRect(x: -1_920, y: 200, width: 1_920, height: 1_055),
        NSRect(x: 1_440, y: -300, width: 1_280, height: 800),
    ]

    @Test func eachLookHasTheBoardSize() {
        #expect(LyricsLook.line.size == NSSize(width: 300, height: 44))
        #expect(LyricsLook.card.size == NSSize(width: 340, height: 128))
        #expect(LyricsLook.lyrics.size == NSSize(width: 360, height: 262))
    }

    @Test(arguments: screens)
    func theIslandHangsEightUnderTheMenuBarCentred(visible: NSRect) {
        for look in LyricsLook.allCases {
            let frame = LyricsGeometry.island(look.size, in: visible)
            #expect(frame.size == look.size)
            #expect(frame.maxY == visible.maxY - 8)
            #expect(abs(frame.midX - visible.midX) <= 0.5)
        }
    }

    @Test(arguments: screens)
    func theIslandGrowsDownFromTheMenuBar(visible: NSRect) {
        let line = LyricsGeometry.island(LyricsLook.line.size, in: visible)
        let card = LyricsGeometry.island(LyricsLook.card.size, in: visible)
        #expect(card.maxY == line.maxY)
        #expect(card.minY < line.minY)
        #expect(abs(card.midX - line.midX) <= 0.5)
    }

    @Test(arguments: screens)
    func everyCornerSitsFourteenInFromTheVisibleFrame(visible: NSRect) {
        for look in LyricsLook.allCases {
            for corner in LyricsCorner.allCases {
                let frame = LyricsGeometry.corner(corner, size: look.size, in: visible)
                #expect(frame.size == look.size)
                let side = corner.isLeading ? frame.minX - visible.minX : visible.maxX - frame.maxX
                let edge = corner.isTop ? visible.maxY - frame.maxY : frame.minY - visible.minY
                #expect(side == 14)
                #expect(edge == 14)
            }
        }
    }

    @Test(arguments: screens)
    func aCornerCardGrowsAwayFromTheEdgesItHangsFrom(visible: NSRect) {
        for corner in LyricsCorner.allCases {
            let line = LyricsGeometry.corner(corner, size: LyricsLook.line.size, in: visible)
            let card = LyricsGeometry.corner(corner, size: LyricsLook.card.size, in: visible)
            if corner.isTop {
                #expect(card.maxY == line.maxY)
                #expect(card.minY < line.minY)
            } else {
                #expect(card.minY == line.minY)
                #expect(card.maxY > line.maxY)
            }
            if corner.isLeading {
                #expect(card.minX == line.minX)
            } else {
                #expect(card.maxX == line.maxX)
            }
        }
    }

    @Test(arguments: screens)
    func aPointSnapsToTheCornerOfItsQuarter(visible: NSRect) {
        let inset: CGFloat = 40
        let points: [(NSPoint, LyricsCorner)] = [
            (NSPoint(x: visible.minX + inset, y: visible.maxY - inset), .topLeading),
            (NSPoint(x: visible.maxX - inset, y: visible.maxY - inset), .topTrailing),
            (NSPoint(x: visible.minX + inset, y: visible.minY + inset), .bottomLeading),
            (NSPoint(x: visible.maxX - inset, y: visible.minY + inset), .bottomTrailing),
        ]
        for (point, corner) in points {
            #expect(LyricsGeometry.nearest(to: point, in: visible) == corner)
        }
    }

    @Test func thePointerPicksTheScreenUnderItOrTheClosestOne() {
        let frames = Self.screens
        #expect(LyricsGeometry.screen(at: NSPoint(x: 10, y: 10), in: frames) == 0)
        #expect(LyricsGeometry.screen(at: NSPoint(x: -100, y: 600), in: frames) == 1)
        #expect(LyricsGeometry.screen(at: NSPoint(x: 2_000, y: -100), in: frames) == 2)
        #expect(LyricsGeometry.screen(at: NSPoint(x: 700, y: 1_000), in: frames) == 0)
        #expect(LyricsGeometry.screen(at: .zero, in: []) == nil)
    }

    @Test(arguments: screens)
    func slotsOutlineEveryOtherCorner(visible: NSRect) {
        let size = LyricsLook.line.size
        let slots = LyricsGeometry.slots(size: size, in: visible, except: .bottomTrailing)
        #expect(Set(slots.keys) == [.topLeading, .topTrailing, .bottomLeading])
        for (corner, frame) in slots {
            #expect(frame == LyricsGeometry.corner(corner, size: size, in: visible))
        }
        #expect(LyricsGeometry.slots(size: size, in: visible, except: nil).count == 4)
    }

    @Test func theMenuBarCardDropsUnderItsItemAndStaysOnScreen() {
        let visible = Self.screens[0]
        let size = LyricsLook.card.size
        let item = NSRect(x: 600, y: visible.maxY, width: 180, height: 24)
        let under = LyricsGeometry.drop(size, below: item, in: visible)
        #expect(under.maxY == visible.maxY - 8)
        #expect(abs(under.midX - item.midX) <= 0.5)
        let edge = NSRect(x: visible.maxX - 60, y: visible.maxY, width: 50, height: 24)
        #expect(LyricsGeometry.drop(size, below: edge, in: visible).maxX == visible.maxX - 8)
        let start = NSRect(x: visible.minX, y: visible.maxY, width: 50, height: 24)
        #expect(LyricsGeometry.drop(size, below: start, in: visible).minX == visible.minX + 8)
    }

    @Test(arguments: screens)
    func desktopTypeSitsAtTheBottomLeft(visible: NSRect) {
        let frame = LyricsGeometry.desktop(height: 90, in: visible)
        #expect(frame.minX == visible.minX + 26)
        #expect(frame.minY == visible.minY + 22)
        #expect(frame.maxX == visible.maxX - 26)
        #expect(frame.height == 90)
    }

    @Test func everyPlaceUsesItsOwnFrame() {
        let visible = Self.screens[1]
        let size = LyricsLook.card.size
        let item = NSRect(x: -900, y: visible.maxY, width: 120, height: 24)
        #expect(
            LyricsGeometry.frame(for: .island, size: size, in: visible)
                == LyricsGeometry.island(size, in: visible))
        #expect(
            LyricsGeometry.frame(for: .corner(.topTrailing), size: size, in: visible)
                == LyricsGeometry.corner(.topTrailing, size: size, in: visible))
        #expect(
            LyricsGeometry.frame(for: .menuBar(anchor: item), size: size, in: visible)
                == LyricsGeometry.drop(size, below: item, in: visible))
        #expect(
            LyricsGeometry.frame(for: .desktop, size: size, in: visible)
                == LyricsGeometry.desktop(height: size.height, in: visible))
    }

    @Test func cornersReadAsWords() {
        #expect(
            LyricsCorner.allCases.map(\.name) == [
                "bottom left", "bottom right", "top left", "top right",
            ])
    }
}
