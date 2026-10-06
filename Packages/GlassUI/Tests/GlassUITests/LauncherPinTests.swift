import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct LauncherPinTests {
    private static let places = LyricsPin.allCases.map(\.title)

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
                "Play / Pause", "Move…", "Pin to screen", "Edit Widgets", "Add Widgets…",
                "Remove Widget",
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

    @Test func pinToScreenListsEveryPlaceInOrderAndPicksOne() throws {
        var picked: [LyricsPin?] = []
        view.onPinLyrics = { picked.append($0) }
        view.widgets = [song]
        view.selectWidget(0)
        view.showActions()
        try press(2)
        #expect(try titles() == Self.places)
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
        #expect(try titles() == Self.places + ["Unpin"])
        try press(6)
        #expect(picked.count == 1 && picked[0] == nil)
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

    @Test func aCancelledDragDoesNotPinAndAFinishedOneUsesTheIdItStartedWith() throws {
        view.widgets = [clock, song]
        view.layoutSubtreeIfNeeded()
        let tile = try #require(view.widgetGrid.tiles.last)
        var dropped: [String] = []
        var ended = 0
        tile.onDragOff = { id, _ in dropped.append(id) }
        tile.onDragEnd = { ended += 1 }
        let far = NSPoint(x: panel.frame.maxX + 2_000, y: panel.frame.midY)
        tile.finishDrag(of: "music", at: far, operation: [], cancelled: true)
        #expect(dropped.isEmpty && ended == 1)
        tile.widgetID = "other"
        tile.finishDrag(of: "music", at: far, operation: [], cancelled: false)
        #expect(dropped == ["music"] && ended == 2)
        tile.finishDrag(of: "music", at: far, operation: .move, cancelled: false)
        #expect(dropped == ["music"] && ended == 2)
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

    @Test func theLyricsWidgetOpensOnlyWhenOpenedAndTheNowPlayingTileOpensThePlayer() {
        let lyrics = WidgetGrid.Widget(
            id: "lyrics", name: "Lyrics",
            verse: .init(
                title: "Low Tide", artist: "Harbour Lights", artwork: nil, isPlaying: true,
                status: .synced, lines: ["Line"], current: 0, progress: 0, remaining: nil),
            action: "Show Lyrics", spoken: "Lyrics: Line")
        var pressed: [String] = []
        var players = 0
        view.onWidget = { pressed.append($0.id) }
        view.onOpenPlayer = { players += 1 }
        view.widgets = [lyrics, song]
        view.tapWidget(0)
        view.openWidget(0)
        view.tapWidget(1)
        view.openWidget(1)
        #expect(pressed == ["lyrics", "music"])
        #expect(players == 1)
    }

    @Test func theWidgetMenuOffersPinToScreenOnlyForMediaTiles() throws {
        var ignored: [LyricsPin?] = []
        view.onPinLyrics = { ignored.append($0) }
        view.pinnedLyrics = .island
        view.widgets = [clock, song]
        view.layoutSubtreeIfNeeded()
        view.openWidgetMenu(0, at: .zero)
        let clockTitles = try #require(view.widgetMenu).rows.map(\.label.stringValue)
        #expect(!clockTitles.contains("Pin to screen"))
        view.closeWidgetMenu()
        view.openWidgetMenu(1, at: .zero)
        let rows = try #require(view.widgetMenu).rows
        let pin = try #require(rows.first { $0.label.stringValue == "Pin to screen" })
        #expect(pin.detail.stringValue == "Island")
        #expect(pin.accessibilityPerformPress())
        #expect(view.widgetMenu == nil && view.choosingAction)
        #expect(try titles() == Self.places + ["Unpin"])
    }

    @Test func pressingTheLyricsTileThroughAccessibilityOpensTheLyrics() throws {
        let lyrics = WidgetGrid.Widget(
            id: "lyrics", name: "Lyrics",
            verse: .init(
                title: "Low Tide", artist: "Harbour Lights", artwork: nil, isPlaying: true,
                status: .synced, lines: ["Line"], current: 0, progress: 0, remaining: nil),
            action: "Show Lyrics", spoken: "Lyrics: Line")
        var opened: [String] = []
        view.onWidget = { opened.append($0.id) }
        view.widgets = [lyrics]
        view.layoutSubtreeIfNeeded()
        let tile = try #require(view.widgetGrid.tiles.first)
        #expect(tile.accessibilityPerformPress())
        #expect(opened == ["lyrics"])
    }
}
