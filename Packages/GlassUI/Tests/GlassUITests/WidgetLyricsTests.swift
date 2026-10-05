import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetLyricsTests {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 548),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let view = LauncherView()
    private let lines = ["Salt on the window", "", "Low tide, low tide", "Every rope", "Far shore"]

    init() {
        panel.contentView = view
        panel.makeFirstResponder(view.field)
    }

    private func song(lyric: WidgetGrid.Lyric?) -> WidgetGrid.Widget {
        .init(
            id: "music", name: "Now Playing",
            track: .init(
                title: "Low Tide", artist: "Harbour Lights", artwork: nil, isPlaying: true,
                lyric: lyric),
            action: "Play / Pause", spoken: "Now playing: Low Tide by Harbour Lights")
    }

    private func verse(
        _ status: WidgetGrid.LyricsStatus, current: Int? = nil
    ) -> WidgetGrid.Widget {
        .init(
            id: "lyrics", name: "Lyrics",
            verse: .init(
                title: "Low Tide", artist: "Harbour Lights", artwork: nil, isPlaying: true,
                status: status, lines: status == .synced || status == .plain ? lines : [],
                current: current, progress: 0.4, remaining: 3),
            action: "Play / Pause", spoken: "Lyrics: line")
    }

    @Test func aLyricReplacesTheEyebrowAndArtistLinesOnTheTrackTile() throws {
        view.widgetSizes = ["music": .init(columns: 3)]
        view.widgets = [song(lyric: nil)]
        view.layoutSubtreeIfNeeded()
        let tile = try #require(view.widgetGrid.tiles.first)
        #expect(tile.track.lyric.isHidden && !tile.track.artist.isHidden)
        view.widgets = [
            song(lyric: .init(text: "Every rope remembers", progress: 0.37, remaining: 4))
        ]
        view.layoutSubtreeIfNeeded()
        #expect(!tile.track.lyric.isHidden && tile.track.artist.isHidden)
        #expect(tile.track.title.stringValue == "Low Tide  Harbour Lights")
        view.widgets = [song(lyric: nil)]
        #expect(tile.track.lyric.isHidden && !tile.track.artist.isHidden)
        #expect(tile.track.title.stringValue == "Low Tide")
    }

    @Test func aNarrowTrackTileKeepsItsArtistInsteadOfTheLyric() throws {
        view.widgets = [
            song(lyric: .init(text: "Every rope remembers", progress: 0.37, remaining: 4))
        ]
        view.layoutSubtreeIfNeeded()
        let tile = try #require(view.widgetGrid.tiles.first)
        #expect(tile.track.lyric.isHidden && !tile.track.artist.isHidden)
    }

    @Test func theLyricsWidgetIsTwoRowsTallAndShowsTheColumnOnlyWhenThereAreLines() throws {
        view.widgets = [verse(.synced, current: 2)]
        view.layoutSubtreeIfNeeded()
        let tile = try #require(view.widgetGrid.tiles.first)
        #expect(abs(tile.frame.height - (2 * 78 + 8)) < 0.01)
        #expect(!tile.verse.isHidden && tile.track.isHidden)
        #expect(tile.accessibilityLabel() == "Lyrics: line")
        view.widgets = [verse(.off)]
        #expect(!tile.verse.isHidden)
        view.widgets = [verse(.synced, current: 0)]
        view.widgets = [song(lyric: nil)]
        #expect(tile.verse.isHidden && !tile.track.isHidden)
    }

    @Test func clickingALineSeeksToIt() throws {
        view.widgets = [verse(.synced, current: 2)]
        view.layoutSubtreeIfNeeded()
        let tile = try #require(view.widgetGrid.tiles.first)
        var sought: [Int] = []
        view.onSeek = { sought.append($0) }
        let column = LyricsColumn(look: .init(pitch: 30, size: 16, rest: 12.5))
        column.frame = NSRect(x: 0, y: 0, width: 300, height: 120)
        column.show(lines, current: 2, progress: 0, remaining: nil, playing: false)
        column.layoutSubtreeIfNeeded()
        let middle = column.bounds.midY
        #expect(column.line(at: NSPoint(x: 20, y: middle)) == 2)
        #expect(column.line(at: NSPoint(x: 20, y: middle + 30)) == 1)
        #expect(column.line(at: NSPoint(x: 20, y: middle - 30)) == 3)
        #expect(column.line(at: NSPoint(x: 20, y: middle - 100)) == nil)
        tile.onSeek?(3)
        #expect(sought == [3])
    }

    @Test func plainLyricsHaveNoCurrentLineToSeekTo() {
        let column = LyricsColumn(look: .init(pitch: 30, size: 16, rest: 12.5))
        column.frame = NSRect(x: 0, y: 0, width: 300, height: 120)
        column.show(lines, current: nil, progress: 0, remaining: nil, playing: false)
        column.layoutSubtreeIfNeeded()
        #expect(column.line(at: NSPoint(x: 20, y: 60)) == nil)
    }
}
