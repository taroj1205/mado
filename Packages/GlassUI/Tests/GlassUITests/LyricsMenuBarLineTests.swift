import AppKit
import Testing

@testable import GlassUI

@MainActor
struct LyricsMenuBarLineTests {
    private let item = LyricsMenuBarLine()

    @Test func itsWidthStaysFixedWhateverTheLine() {
        item.show(LyricsFloatRig.song(.synced, current: 3, playing: true))
        #expect(item.intrinsicContentSize == NSSize(width: LyricsMenuBarLine.width, height: 22))
        let long = WidgetGrid.Verse(
            title: "Low Tide", artist: "", artwork: nil, isPlaying: true, status: .synced,
            lines: [String(repeating: "Every rope remembers where it’s tied ", count: 4)],
            current: 0, progress: 0.5, remaining: 3)
        item.show(long)
        #expect(item.intrinsicContentSize.width == LyricsMenuBarLine.width)
    }

    @Test func theEqualizerMovesOnlyWhilePlaying() {
        item.show(LyricsFloatRig.song(.synced, current: 1, playing: true))
        #expect(item.equalizer.isActive)
        item.show(LyricsFloatRig.song(.synced, current: 1, playing: false))
        #expect(!item.equalizer.isActive)
    }

    @Test func itReadsAsTheLyricsGroupWithTheSungLine() {
        item.show(LyricsFloatRig.synced)
        #expect(item.accessibilityLabel() == "Lyrics")
        #expect(item.accessibilityValue() as? String == LyricsFloatRig.lines[1])
    }

    @Test func clicksGoToTheStatusItemButton() {
        item.frame = NSRect(x: 0, y: 0, width: 120, height: 22)
        #expect(item.hitTest(NSPoint(x: 60, y: 11)) == nil)
    }

    @Test func withoutATimedLineItShowsTheSong() {
        item.show(LyricsFloatRig.song(.missing, current: nil, playing: true))
        #expect(item.accessibilityValue() as? String == "Low Tide · Harbour Lights")
        #expect(item.intrinsicContentSize.width == LyricsMenuBarLine.width)
    }
}
