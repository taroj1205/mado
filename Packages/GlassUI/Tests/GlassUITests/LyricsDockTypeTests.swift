import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite(.silentWindows, .enabled(if: !NSScreen.screens.isEmpty, "Laying out lyrics needs a screen"))
struct LyricsDockTypeTests {
    private static let long =
        "「残酷だったなぁ人生は」思っていたのに、いま君に会って思いきり泣いてみたい気持ちだけが残る"
    private static let narrow = LyricsBarSpot.typeWidths.lowerBound
    private static let wide = LyricsBarSpot.typeWidths.upperBound
    private let type = LyricsDockType()

    private func verse(_ lines: [String], current: Int = 1) -> WidgetGrid.Verse {
        WidgetGrid.Verse(
            title: "Low Tide", artist: "Harbour Lights", artwork: nil, isPlaying: false,
            status: .synced, lines: lines, current: current, progress: 0.5, remaining: nil)
    }

    private func show(_ lines: [String], width: CGFloat) {
        type.frame = NSRect(x: 0, y: 0, width: width, height: LyricsBarSpot.typeHeight)
        type.show(verse(lines))
        type.layoutSubtreeIfNeeded()
    }

    @Test func aLineThatFitsLeavesTheRestHeightTheSpotAllowsFor() {
        show(["Before", "Short", "After"], width: Self.wide)
        #expect(type.contentHeight(for: Self.wide) == LyricsBarSpot.typeRest)
    }

    @Test func aLongLineWrapsOntoMoreLinesInsteadOfCuttingOff() {
        show(["Before", Self.long, "After"], width: Self.wide)
        let one = LyricsBarSpot.typeRest - 24
        #expect(type.line.frame.height > one - 15 * 2 - 4 * 2 + 24)
        #expect(type.line.frame.height >= 48)
        #expect(type.line.accessibilityValue() == nil)
        #expect(type.accessibilityValue() as? String == Self.long)
    }

    @Test func theTallestRowsStillFitTheSlotAtTheNarrowestWidth() {
        let tall = String(repeating: "Every rope remembers where it is tied. ", count: 6)
        show([tall, tall, tall], width: Self.narrow)
        #expect(type.contentHeight(for: Self.narrow) <= LyricsBarSpot.typeHeight)
    }

    @Test func theRowsSitOnTheBottomEdgeWithTheNextLineLowest() {
        show(["Before", Self.long, "After"], width: Self.narrow)
        #expect(type.next.frame.minY == 0)
        #expect(type.line.frame.minY > type.next.frame.maxY)
        #expect(type.previous.frame.minY > type.line.frame.maxY)
        #expect(type.previous.frame.maxY <= LyricsBarSpot.typeHeight)
    }

    @Test func aWiderSlotNeedsFewerLines() {
        show(["Before", Self.long, "After"], width: Self.narrow)
        let tight = type.line.frame.height
        show(["Before", Self.long, "After"], width: Self.wide)
        #expect(type.line.frame.height < tight)
    }
}
