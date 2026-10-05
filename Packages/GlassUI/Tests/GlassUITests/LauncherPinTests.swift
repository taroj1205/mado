import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct LauncherPinTests {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 548),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let view = LauncherView()
    private let clock = WidgetGrid.Widget(
        id: "clock", name: "Clock", value: "9:41", detail: "Wed 30 Sep", action: "Open Clock",
        spoken: "Time: 9:41 AM, Wednesday 30 September")
    private let song = WidgetGrid.Widget(
        id: "music", name: "Now Playing",
        track: .init(title: "Low Tide", artist: "Harbour Lights", artwork: nil, isPlaying: true),
        action: "Play / Pause", spoken: "Now playing: Low Tide by Harbour Lights")

    init() {
        panel.contentView = view
        panel.makeFirstResponder(view.field)
    }

    private func rows() throws -> [ActionRow] {
        try #require(view.actionPanel).rows
    }

    private func titles() throws -> [String] {
        try rows().map(\.label.stringValue)
    }

    private func press(_ index: Int) throws {
        let row = try rows()[index]
        let action = try #require(row.onPress)
        action()
    }

    private func click(_ type: NSEvent.EventType, at point: NSPoint) throws -> NSEvent {
        try #require(
            NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1,
                pressure: 1))
    }

    @Test func aMediaWidgetsActionsOfferPinToScreenAfterMoveAndShowTheCurrentPlace() throws {
        var ignored: [LyricsPin?] = []
        view.onPinLyrics = { ignored.append($0) }
        view.pinnedLyrics = .corner
        view.widgets = [song]
        view.selectWidget(0)
        view.showActions()
        #expect(
            try titles() == [
                "Play / Pause", "Move…", "Pin to screen", "Edit Widgets", "Remove Widget",
            ])
        #expect(try rows()[2].detail.stringValue == "Corner card")
    }

    @Test func otherWidgetsAndAViewWithoutAHandlerHaveNoPinEntry() throws {
        var ignored: [LyricsPin?] = []
        view.onPinLyrics = { ignored.append($0) }
        view.widgets = [clock]
        view.selectWidget(0)
        view.showActions()
        #expect(try !titles().contains("Pin to screen"))
        view.closeActions()
        view.onPinLyrics = nil
        view.widgets = [song]
        view.showActions()
        #expect(try !titles().contains("Pin to screen"))
    }

    @Test func pinToScreenListsTheFourPlacesInTheDesignsOrderAndPicksOne() throws {
        var picked: [LyricsPin?] = []
        view.onPinLyrics = { picked.append($0) }
        view.widgets = [song]
        view.selectWidget(0)
        view.showActions()
        try press(2)
        #expect(try titles() == ["Island", "Corner card", "Menu bar line", "Desktop type"])
        try press(2)
        #expect(picked == [.menuBar])
        #expect(!view.choosingAction)
    }

    @Test func whenPinnedTheChoicesCheckThePlaceAndOfferUnpin() throws {
        var picked: [LyricsPin?] = []
        view.onPinLyrics = { picked.append($0) }
        view.pinnedLyrics = .island
        view.widgets = [song]
        view.selectWidget(0)
        view.showActions()
        try press(2)
        #expect(
            try titles() == ["Island", "Corner card", "Menu bar line", "Desktop type", "Unpin"])
        try press(4)
        #expect(picked.count == 1 && picked[0] == nil)
    }

    @Test func theMoreButtonShowsOnlyOnASelectedOrHoveredMediaTile() throws {
        view.widgets = [clock, song]
        let media = try #require(view.widgetGrid.tiles.last)
        let other = try #require(view.widgetGrid.tiles.first)
        #expect(media.more.isHidden && other.more.isHidden)
        view.selectWidget(1)
        #expect(!media.more.isHidden)
        view.selectWidget(0)
        #expect(media.more.isHidden && other.more.isHidden)
        media.hovered = true
        #expect(!media.more.isHidden)
        other.hovered = true
        #expect(other.more.isHidden)
        media.editing = true
        #expect(media.more.isHidden)
    }

    @Test func clickingTheMoreButtonOpensTheTilesActions() throws {
        var ignored: [LyricsPin?] = []
        view.onPinLyrics = { ignored.append($0) }
        view.widgets = [song]
        view.layoutSubtreeIfNeeded()
        let tile = try #require(view.widgetGrid.tiles.first)
        view.selectWidget(0)
        let centre = tile.convert(
            NSPoint(x: tile.more.frame.midX, y: tile.more.frame.midY), to: nil)
        tile.mouseDown(with: try click(.leftMouseDown, at: centre))
        #expect(view.choosingAction)
        #expect(try titles().contains("Pin to screen"))
    }

    @Test func rightClickingATileSelectsItAndOpensItsActions() throws {
        view.widgets = [clock, song]
        view.layoutSubtreeIfNeeded()
        let tile = try #require(view.widgetGrid.tiles.first)
        tile.rightMouseDown(with: try click(.rightMouseDown, at: NSPoint(x: 40, y: 480)))
        #expect(view.selectedWidget == 0)
        #expect(view.choosingAction)
        #expect(try titles().first == "Open Clock")
    }

    @Test func draggingAMediaTileFarOffThePanelPinsAnIslandButNearOrOtherTilesDoNot() {
        var picked: [LyricsPin?] = []
        view.onPinLyrics = { picked.append($0) }
        view.widgets = [clock, song]
        view.layoutSubtreeIfNeeded()
        let grid = view.widgetGrid
        let far = NSPoint(x: panel.frame.maxX + 2_000, y: panel.frame.midY)
        grid.dragOff("clock", at: far)
        grid.dragOff("music", at: NSPoint(x: panel.frame.midX, y: panel.frame.midY))
        #expect(picked.isEmpty)
        grid.dragOff("music", at: far)
        #expect(picked == [.island])
    }

    @Test func aTrackThatIsBeingLookedUpShowsASkeletonInPlaceOfTheLyricLine() throws {
        view.widgetSizes = ["music": .init(columns: 3)]
        let lookingUp = WidgetGrid.Widget(
            id: "music", name: "Now Playing",
            track: .init(
                title: "Low Tide", artist: "Harbour Lights", artwork: nil, isPlaying: true,
                lookingUp: true),
            action: "Play / Pause", spoken: "Now playing: Low Tide by Harbour Lights")
        view.widgets = [lookingUp]
        view.layoutSubtreeIfNeeded()
        let track = try #require(view.widgetGrid.tiles.first).track
        #expect(!track.lookup.isHidden && track.lyric.isHidden && track.artist.isHidden)
        view.widgets = [song]
        view.layoutSubtreeIfNeeded()
        #expect(track.lookup.isHidden && !track.artist.isHidden)
    }
}
