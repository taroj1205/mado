import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite(.silentWindows, .enabled(if: !NSScreen.screens.isEmpty, "Placing lyrics needs a screen"))
struct LyricsFloatPointerTests {
    private let rig = LyricsFloatRig()

    private var float: LyricsFloat {
        rig.float
    }

    private var middle: NSPoint {
        NSPoint(x: float.frame.midX, y: float.frame.midY)
    }

    @Test func aQuarterSecondHoverGrowsTheIslandDown() {
        rig.show(.island)
        defer { float.hide(animated: false) }
        let resting = float.frame
        rig.hover(middle)
        rig.wait(200)
        #expect(float.frame == resting)
        rig.wait(60)
        #expect(float.frame.size == LyricsLook.card.size)
        #expect(float.frame.maxY == resting.maxY)
        #expect(abs(float.frame.midX - resting.midX) <= 0.5)
        #expect(rig.card.look == .card)
        rig.hover(LyricsFloatRig.away)
        #expect(float.frame == resting)
        #expect(rig.card.look == .line)
    }

    @Test func leavingBeforeAQuarterSecondStartsTheWaitAgain() {
        rig.show(.island)
        defer { float.hide(animated: false) }
        let resting = float.frame
        rig.hover(middle)
        rig.wait(200)
        rig.hover(LyricsFloatRig.away)
        rig.hover(middle)
        rig.wait(200)
        #expect(float.frame == resting)
    }

    @Test func aBottomCornerGrowsUpward() {
        rig.show(.corner(.bottomTrailing))
        defer { float.hide(animated: false) }
        let resting = float.frame
        rig.hover(middle)
        rig.wait(300)
        #expect(float.frame.size == LyricsLook.card.size)
        #expect(float.frame.minY == resting.minY)
        #expect(float.frame.maxX == resting.maxX)
    }

    @Test func showingAgainKeepsTheGrownCard() {
        rig.show(.island)
        defer { float.hide(animated: false) }
        rig.hover(middle)
        rig.wait(300)
        rig.verse = LyricsFloatRig.song(.synced, current: 3, playing: true)
        rig.show(.island)
        #expect(float.frame.size == LyricsLook.card.size)
    }

    @Test(arguments: [LyricsLook.card, .lyrics])
    func biggerLooksDoNotGrow(look: LyricsLook) {
        rig.look = look
        rig.show(.island)
        defer { float.hide(animated: false) }
        let resting = float.frame
        rig.hover(middle)
        rig.wait(500)
        #expect(float.frame == resting)
    }

    @Test func withMotionTheGrowAnimatesToTheCard() throws {
        let screen = try #require(rig.screen)
        float.reducesMotion = { false }
        rig.show(.island)
        defer { float.hide(animated: false) }
        rig.hover(middle)
        rig.wait(300)
        #expect(
            float.target == LyricsGeometry.island(LyricsLook.card.size, in: screen.visibleFrame))
    }

    @Test func clicksPassThroughExceptOnTheControls() {
        rig.look = .card
        rig.show(.island)
        defer { float.hide(animated: false) }
        rig.hover(rig.centre(of: rig.card.next))
        #expect(!float.panel.ignoresMouseEvents)
        rig.hover(rig.centre(of: rig.card.title))
        #expect(float.panel.ignoresMouseEvents)
        rig.hover(LyricsFloatRig.away)
        #expect(float.panel.ignoresMouseEvents)
    }

    @Test func theRestingLineIsClickThroughEverywhere() {
        rig.show(.island)
        defer { float.hide(animated: false) }
        rig.hover(middle)
        #expect(float.panel.ignoresMouseEvents)
    }

    @Test func theCornerCardBodyTakesTheClickToDrag() {
        rig.show(.corner(.topLeading))
        defer { float.hide(animated: false) }
        rig.hover(middle)
        #expect(!float.panel.ignoresMouseEvents)
        #expect(rig.card.acceptsFirstMouse(for: nil))
        rig.hover(LyricsFloatRig.away)
        #expect(float.panel.ignoresMouseEvents)
    }

    @Test func draggingSnapsToTheNearestCornerAndSaysWhere() throws {
        let screen = try #require(rig.screen)
        let visible = screen.visibleFrame
        rig.show(.corner(.topLeading))
        defer { float.hide(animated: false) }
        rig.hover(middle)
        float.drag(.began)
        let slots = float.slots.filter(\.value.isVisible)
        #expect(Set(slots.keys) == [.topTrailing, .bottomLeading, .bottomTrailing])
        let size = float.frame.size
        for (corner, slot) in slots {
            #expect(slot.frame == LyricsGeometry.corner(corner, size: size, in: visible))
            #expect(slot.ignoresMouseEvents)
        }
        rig.point = NSPoint(x: visible.maxX - 120, y: visible.minY + 60)
        float.drag(.moved)
        #expect(float.frame.midX > visible.midX)
        #expect(!float.panel.ignoresMouseEvents)
        float.drag(.ended)
        #expect(rig.moves.map(\.0) == [.bottomTrailing])
        #expect(rig.moves.first?.1 == screen)
        #expect(float.frame == LyricsGeometry.corner(.bottomTrailing, size: size, in: visible))
        #expect(!float.slots.values.map(\.isVisible).contains(true))
    }

    @Test func aClickWithoutDraggingStaysAndSaysNothing() {
        rig.show(.corner(.bottomLeading))
        defer { float.hide(animated: false) }
        let resting = float.frame
        rig.hover(middle)
        float.drag(.began)
        float.drag(.ended)
        #expect(rig.moves.isEmpty)
        #expect(float.frame == resting)
    }

    @Test func onlyTheCornerCardDrags() {
        rig.show(.island)
        defer { float.hide(animated: false) }
        let resting = float.frame
        rig.hover(middle)
        float.drag(.began)
        rig.point = .zero
        float.drag(.moved)
        float.drag(.ended)
        #expect(float.frame == resting)
        #expect(rig.moves.isEmpty)
    }

    @Test func theMenuBarCardDropsUnderItsItemAndClosesOnAClickOutside() throws {
        let screen = try #require(rig.screen)
        let visible = screen.visibleFrame
        let item = NSRect(x: visible.midX, y: visible.maxY, width: 160, height: 22)
        rig.show(.menuBar(anchor: item))
        defer { float.hide(animated: false) }
        #expect(float.frame == LyricsGeometry.drop(LyricsLook.card.size, below: item, in: visible))
        rig.buttons = 1
        rig.hover(NSPoint(x: item.midX, y: item.midY))
        rig.hover(middle)
        #expect(float.isShown)
        rig.hover(NSPoint(x: visible.minX + 5, y: visible.minY + 5))
        #expect(!float.isShown)
        #expect(rig.dismissals == 1)
    }

    @Test func movingThePointerWithoutAClickKeepsTheMenuBarCard() throws {
        let screen = try #require(rig.screen)
        let item = NSRect(
            x: screen.visibleFrame.midX, y: screen.visibleFrame.maxY, width: 160, height: 22)
        rig.show(.menuBar(anchor: item))
        defer { float.hide(animated: false) }
        rig.hover(.zero)
        #expect(float.isShown)
        #expect(rig.dismissals == 0)
    }
}
