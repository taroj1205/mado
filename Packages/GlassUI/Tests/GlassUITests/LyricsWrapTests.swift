import AppKit
import Testing

@testable import GlassUI

@MainActor
struct LyricsWrapTests {
    private static let font = NSFont.systemFont(ofSize: 20, weight: .semibold)
    private static let text =
        "Every rope remembers where it is tied, and every tide forgets the boats"

    @Test func aWiderBoxNeedsFewerLines() {
        let narrow = LyricsWrap(Self.text, font: Self.font, width: 200, lines: 8)
        let wide = LyricsWrap(Self.text, font: Self.font, width: 500, lines: 8)
        #expect(narrow.rects.count > wide.rects.count)
        #expect(wide.rects.count >= 2)
    }

    @Test func everyLineIsOneFixedHeightSoRowsCanBeStacked() {
        let wrap = LyricsWrap(Self.text, font: Self.font, width: 200, lines: 8)
        let line = LyricsWrap.lineHeight(of: Self.font)
        #expect(wrap.rects.allSatisfy { $0.height == line })
        #expect(wrap.height == line * CGFloat(wrap.rects.count))
    }

    @Test func theLineCapCutsTheLastLineInsteadOfGrowingForever() {
        let wrap = LyricsWrap(Self.text, font: Self.font, width: 120, lines: 2)
        #expect(wrap.rects.count == 2)
    }

    @Test func noTextTakesNoLines() {
        #expect(LyricsWrap("", font: Self.font, width: 200, lines: 4).rects.isEmpty)
    }
}
