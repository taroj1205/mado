import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetResizeTests {
    private static let frame = NSRect(x: 400, y: 200, width: 760, height: 476)
    private static let step = (760 - 5 * 10) / 6.0 + 10

    private let panel = NSPanel(
        contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
        defer: false)
    private let view = LauncherView()

    init() {
        panel.contentView = view
        view.widgets = (1...7).map(numbered)
        panel.makeFirstResponder(view.field)
        view.layoutSubtreeIfNeeded()
    }

    @Test func draggingTheHandleWidensTheTileInWholeColumnsAndLettingGoSavesIt() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.editWidgets()
        view.layoutSubtreeIfNeeded()
        let tile = view.widgetGrid.tiles[0]
        #expect(tile.resizer.isHidden)
        view.selectWidget(0)
        #expect(!tile.resizer.isHidden)
        #expect(
            tile.accessibilityCustomActions()?.map(\.name) == [
                "Remove", "Add to Selection", "Make Wider", "Make Narrower",
            ])
        let handle = tile.convert(
            NSPoint(x: tile.resizer.frame.midX, y: tile.resizer.frame.midY), to: nil)
        let narrow = tile.frame.width
        tile.mouseDown(with: try mouse(.leftMouseDown, at: handle))
        tile.mouseDragged(
            with: try mouse(.leftMouseDragged, at: moved(handle, by: Self.step * 0.4)))
        #expect(view.widgetGrid.trial.isEmpty)
        tile.mouseDragged(
            with: try mouse(.leftMouseDragged, at: moved(handle, by: Self.step * 0.6)))
        #expect(view.widgetGrid.trial == ["1": 2])
        view.layoutSubtreeIfNeeded()
        #expect(view.widgetGrid.tiles[0].frame.width > narrow * 2)
        #expect(edits.isEmpty)
        tile.mouseUp(with: try mouse(.leftMouseUp, at: handle))
        #expect(edits == [.resize("1", columns: 2)])
        #expect(view.widgetGrid.trial.isEmpty)
        #expect(view.editBar.hint.stringValue == "Widget 1 resized · 2 of 6 columns")
        #expect(view.selectedWidget == 0)
    }

    @Test func wideningStopsAtTheWidestSizeThatStillFits() {
        view.widgets = (1...11).map(numbered)
        view.editWidgets()
        view.widgetGrid.stretch("1", by: Self.step * 2)
        #expect(view.widgetGrid.trial == ["1": 2])
        view.widgetGrid.stretch("1", by: Self.step * -1)
        #expect(view.widgetGrid.trial.isEmpty)
        view.widgets = (1...12).map(numbered)
        #expect(view.widgetGrid.fitted("1", adding: 1) == nil)
    }

    @Test func commandEqualsAndMinusGrowAndShrinkTheSelectedWidget() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.editWidgets()
        view.selectWidget(0)
        #expect(view.performKeyEquivalent(with: try key(kVK_ANSI_Equal, "=", [.command])))
        #expect(edits == [.resize("1", columns: 2)])
        #expect(view.performKeyEquivalent(with: try key(kVK_ANSI_Minus, "-", [.command])))
        #expect(edits.count == 1)
        view.widgetSizes = ["1": 3]
        #expect(view.performKeyEquivalent(with: try key(kVK_ANSI_Minus, "-", [.command])))
        #expect(edits.last == .resize("1", columns: 2))
    }

    @Test func commandDraggingACornerResizesWithoutEditModeAndElsewhereItMoves() throws {
        var edits: [WidgetSettings.Edit] = []
        var ran: [String] = []
        view.onWidgetEdit = { edits.append($0) }
        view.onWidget = { ran.append($0.id) }
        let tile = view.widgetGrid.tiles[1]
        #expect(tile.resizer.isHidden)
        let corner = tile.convert(
            NSPoint(x: tile.bounds.maxX - 4, y: tile.bounds.minY + 4), to: nil)
        tile.mouseDown(with: try mouse(.leftMouseDown, at: corner, [.command]))
        #expect(tile.dragStart == nil)
        tile.mouseDragged(with: try mouse(.leftMouseDragged, at: moved(corner, by: Self.step)))
        #expect(view.widgetGrid.trial == ["2": 2])
        tile.mouseUp(with: try mouse(.leftMouseUp, at: corner))
        #expect(edits == [.resize("2", columns: 2)])
        #expect(ran.isEmpty)
        let middle = tile.convert(NSPoint(x: tile.bounds.midX, y: tile.bounds.midY), to: nil)
        tile.mouseDown(with: try mouse(.leftMouseDown, at: middle, [.command]))
        #expect(tile.dragStart != nil)
        #expect(tile.resizeStart == nil)
        let plain = tile.convert(NSPoint(x: tile.bounds.maxX - 4, y: tile.bounds.minY + 4), to: nil)
        tile.mouseUp(with: try mouse(.leftMouseUp, at: plain))
        tile.mouseDown(with: try mouse(.leftMouseDown, at: plain))
        #expect(tile.resizeStart == nil)
        #expect(ran.isEmpty)
        #expect(view.selectedWidget != nil)
    }

    @Test func savedSizesStayBetweenTheWidgetsNarrowestAndHalfTheRow() {
        let track = WidgetGrid.Track(title: "Song", artist: "Band", artwork: nil, isPlaying: true)
        view.widgets =
            [.init(id: "music", name: "Now Playing", track: track, action: "", spoken: "")]
            + (1...3).map(numbered)
        view.widgetSizes = ["music": 1, "1": 9, "2": 3]
        #expect(view.widgetGrid.widgets.map(\.span) == [2, 3, 3, 1])
    }

    @Test func tilesOnASideRailKeepTheirWidth() {
        view.widgetSpots = ["2": .leftTop, "3": .aboveLeft]
        let resizable = Dictionary(
            uniqueKeysWithValues: zip(view.widgetGrid.shown.map(\.id), view.widgetGrid.tiles)
                .map { ($0, $1.resizable) })
        #expect(resizable["1"] == true)
        #expect(resizable["3"] == true)
        #expect(resizable["2"] == false)
    }

    @Test func sizesAreSavedForAddedWidgetsAndGoWithARemovedOne() {
        let available = ["clock", "system"]
        var widgets = WidgetSettings()
        widgets.apply(.resize("clock", columns: 3), from: available)
        widgets.apply(.resize("weather", columns: 2), from: available)
        #expect(widgets.sizes(from: available) == ["clock": 3])
        widgets.apply(.remove("clock"), from: available)
        widgets.apply(.add("clock"), from: available)
        #expect(widgets.sizes(from: available).isEmpty)
    }

    private func moved(_ point: NSPoint, by distance: CGFloat) -> NSPoint {
        NSPoint(x: point.x + distance, y: point.y)
    }

    private func mouse(
        _ type: NSEvent.EventType, at point: NSPoint, _ flags: NSEvent.ModifierFlags = []
    ) throws -> NSEvent {
        try #require(
            NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: flags, timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1,
                pressure: 1))
    }

    private func key(
        _ keyCode: Int, _ characters: String, _ modifiers: NSEvent.ModifierFlags
    ) throws -> NSEvent {
        try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, characters: characters,
                charactersIgnoringModifiers: characters, isARepeat: false,
                keyCode: UInt16(keyCode)))
    }

    private func numbered(_ number: Int) -> WidgetGrid.Widget {
        .init(
            id: "\(number)", name: "Widget \(number)", value: "\(number)", detail: "",
            action: "Open \(number)", spoken: "Widget \(number)")
    }
}
