import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetTrackTests {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 548),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let view = LauncherView()
    private let clock = WidgetGrid.Widget(
        id: "clock", value: "9:41", detail: "Wed 30 Sep", action: "Open Clock",
        spoken: "Time: 9:41 AM, Wednesday 30 September")

    init() {
        panel.contentView = view
        panel.makeFirstResponder(view.field)
    }

    @Test func aTrackWidgetSpansTwoColumnsAndWrapsWhenTheRowIsFull() throws {
        let song = song(isPlaying: true)
        view.widgets = [clock, song, clock]
        view.layoutSubtreeIfNeeded()
        let column = (732 - 5 * 8) / 6.0
        let frames = view.widgetGrid.tiles.map(\.frame)
        #expect(frames.map(\.minY) == [12, 12, 12])
        #expect(abs(frames[1].minX - (14 + column + 8)) < 0.01)
        #expect(abs(frames[1].width - (2 * column + 8)) < 0.01)
        #expect(abs(frames[2].minX - frames[1].maxX - 8) < 0.01)
        view.widgets = Array(repeating: clock, count: 5) + [song]
        view.layoutSubtreeIfNeeded()
        let wrapped = try #require(view.widgetGrid.tiles.last).frame
        #expect(wrapped.minX == 14)
        #expect(abs(wrapped.minY - (12 + 78 + 8)) < 0.01)
        #expect(abs(view.widgetGrid.frame.height - (12 + 2 * 78 + 8 + 4)) < 0.01)
    }

    @Test func theStripKeepsATrackOnlyWhenItsTwoColumnsFit() {
        view.widgetLayout = .strip
        view.widgets = Array(repeating: clock, count: 4) + [song(isPlaying: true), clock]
        view.layoutSubtreeIfNeeded()
        #expect(view.widgetGrid.shown.count == 5)
        #expect(view.widgetGrid.tiles.last?.frame.maxX == view.widgetGrid.bounds.maxX - 14)
        view.widgets = Array(repeating: clock, count: 5) + [song(isPlaying: true)]
        #expect(view.widgetGrid.shown.count == 5)
    }

    @Test func aTrackTileShowsTheSongAndItsPlayState() throws {
        view.widgets = [clock, song(isPlaying: true)]
        view.layoutSubtreeIfNeeded()
        let tile = try #require(view.widgetGrid.tiles.last)
        #expect(tile.value.isHidden && tile.detail.isHidden && !tile.track.isHidden)
        #expect(tile.track.title.stringValue == "Low Tide")
        #expect(tile.track.artist.stringValue == "Harbour Lights")
        let pause = tile.track.toggle.image
        let toggle = tile.track.toggle.alignmentRect(forFrame: tile.track.toggle.frame)
        #expect(tile.track.art.image != nil)
        #expect(tile.accessibilityLabel() == "Now playing: Low Tide by Harbour Lights")
        #expect(abs(tile.track.art.frame.width - 48) < 0.01)
        #expect(abs(tile.convert(tile.track.art.bounds, from: tile.track.art).minX - 10) < 0.01)
        let cover = NSImage(size: NSSize(width: 4, height: 4), flipped: false) { rect in
            NSColor.red.setFill()
            rect.fill()
            return true
        }
        let artwork = try #require(cover.tiffRepresentation)
        view.pressWidget(1)
        view.widgets = [clock, song(isPlaying: false, artwork: artwork)]
        #expect(view.widgetGrid.tiles.last === tile)
        #expect(tile.track.toggle.image !== pause)
        view.layoutSubtreeIfNeeded()
        #expect(tile.track.toggle.alignmentRect(forFrame: tile.track.toggle.frame) == toggle)
        #expect(tile.track.art.image?.size == NSSize(width: 4, height: 4))
        #expect(tile.accessibilityLabel() == "Paused: Low Tide by Harbour Lights")
        #expect(view.actionLabel.stringValue == "Play / Pause")
        view.widgets = [clock, clock]
        #expect(tile.track.isHidden && !tile.value.isHidden)
    }

    @Test func prevAndNextSkipAndSelectTheTileWhileTheRestPlaysOrPauses() throws {
        var skips: [WidgetGrid.Skip] = []
        var pressed: [String] = []
        view.onSkip = { skips.append($0) }
        view.onWidget = { pressed.append($0.id) }
        view.widgets = [clock, song(isPlaying: true)]
        view.layoutSubtreeIfNeeded()
        let track = try #require(view.widgetGrid.tiles.last?.track)
        let centre = { (glyph: NSView) in
            let frame = track.convert(glyph.bounds, from: glyph)
            return NSPoint(x: frame.midX, y: frame.midY)
        }
        #expect(track.skip(at: centre(track.previous)) == .previous)
        #expect(track.skip(at: centre(track.next)) == .next)
        #expect(track.skip(at: centre(track.toggle)) == nil)
        #expect(track.skip(at: centre(track.art)) == nil)
        let tile = try #require(view.widgetGrid.tiles.last)
        let actions = tile.accessibilityCustomActions() ?? []
        #expect(actions.map(\.name) == ["Previous Track", "Next Track"])
        #expect(actions.last?.handler?() == true)
        #expect(skips == [.next])
        #expect(view.selectedWidget == 1)
        #expect(pressed.isEmpty)
        view.widgets = [clock, clock]
        #expect(tile.accessibilityCustomActions()?.isEmpty != false)
    }

    private func song(isPlaying: Bool, artwork: Data? = nil) -> WidgetGrid.Widget {
        .init(
            id: "music",
            track: .init(
                title: "Low Tide", artist: "Harbour Lights", artwork: artwork,
                isPlaying: isPlaying),
            action: "Play / Pause",
            spoken: "\(isPlaying ? "Now playing" : "Paused"): Low Tide by Harbour Lights")
    }
}
