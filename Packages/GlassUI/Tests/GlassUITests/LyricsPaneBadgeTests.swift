import AppCore
import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct LyricsPaneBadgeTests {
    private func badge(_ status: WidgetGrid.LyricsStatus, from source: Lyrics.Source) -> String {
        let pane = LyricsPane()
        pane.show(
            .init(
                title: "Low Tide", artist: "Harbour Lights", artwork: nil, isPlaying: true,
                status: status, lines: ["Salt"], current: 0, source: source))
        return pane.badge.name.stringValue
    }

    @Test func syncedLyricsNameWhereTheyCameFrom() {
        #expect(badge(.synced, from: .lrclib) == "Synced · LRCLIB")
        #expect(badge(.synced, from: .kuGou) == "Synced · KuGou")
        #expect(badge(.plain, from: .lrclib) == "Not synced")
    }
}
