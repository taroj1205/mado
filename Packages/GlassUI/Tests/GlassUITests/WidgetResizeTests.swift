import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetResizeTests {
    private static let frame = NSRect(x: 400, y: 200, width: 760, height: 476)
    private static let step = CGSize(width: (732 - 5 * 8) / 6.0 + 8, height: 78 + 8)

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

    @Test func draggingTheHandleResizesTheTileInWholeCellsAndLettingGoSavesIt() throws {
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
                "Remove", "Add to Selection", "Make Wider", "Make Narrower", "Make Taller",
                "Make Shorter",
            ])
        let handle = tile.convert(
            NSPoint(x: tile.resizer.frame.midX, y: tile.resizer.frame.midY), to: nil)
        let narrow = tile.frame.width
        tile.mouseDown(with: try mouse(.leftMouseDown, at: handle))
        tile.mouseDragged(
            with: try mouse(.leftMouseDragged, at: moved(handle, by: Self.step.scaled(0.4, 0))))
        #expect(view.widgetGrid.trial.isEmpty)
        tile.mouseDragged(
            with: try mouse(.leftMouseDragged, at: moved(handle, by: Self.step.scaled(0.6, 0))))
        #expect(view.widgetGrid.trial == ["1": .init(columns: 2)])
        view.layoutSubtreeIfNeeded()
        let grid = view.widgetGrid
        #expect(abs(grid.tiles[0].frame.width - (narrow + 0.6 * Self.step.width)) < 0.5)
        #expect(abs(grid.guide.frame.width - (2 * narrow + 8)) < 0.5)
        #expect(!grid.guide.isHidden && !grid.sizeLabel.isHidden)
        #expect(grid.sizeLabel.title == "Medium · 2 × 1")
        #expect(edits.isEmpty)
        tile.mouseUp(with: try mouse(.leftMouseUp, at: handle))
        #expect(edits == [.resize("1", .init(columns: 2))])
        #expect(view.widgetGrid.trial.isEmpty)
        #expect(view.editBar.hint.stringValue == "Widget 1 resized · Medium · 2 × 1")
        #expect(view.selectedWidget == 0)
    }

    @Test func draggingTheHandleDownMakesTheTileTallerAndTheOthersMakeRoom() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.editWidgets()
        view.selectWidget(0)
        view.layoutSubtreeIfNeeded()
        let tile = view.widgetGrid.tiles[0]
        let handle = tile.convert(
            NSPoint(x: tile.resizer.frame.midX, y: tile.resizer.frame.midY), to: nil)
        let short = tile.frame.height
        tile.mouseDown(with: try mouse(.leftMouseDown, at: handle))
        tile.mouseDragged(
            with: try mouse(.leftMouseDragged, at: moved(handle, by: Self.step.scaled(0, -1))))
        #expect(view.widgetGrid.trial.isEmpty)
        tile.mouseDragged(
            with: try mouse(.leftMouseDragged, at: moved(handle, by: Self.step.scaled(0.6, 0.6))))
        #expect(view.widgetGrid.trial == ["1": .init(columns: 2, rows: 2)])
        view.layoutSubtreeIfNeeded()
        let tall = view.widgetGrid.guide.frame
        #expect(abs(tall.height - (2 * short + 8)) < 0.01)
        #expect(view.widgetGrid.tiles[1].frame.minX > tall.maxX)
        tile.mouseUp(with: try mouse(.leftMouseUp, at: handle))
        #expect(edits == [.resize("1", .init(columns: 2, rows: 2))])
        #expect(view.editBar.hint.stringValue == "Widget 1 resized · Large · 2 × 2")
    }

    @Test func aTallTileDoesNotFitAFullPanelAndTheFullestSizeThatFitsWins() {
        view.widgets = (1...17).map(numbered)
        view.editWidgets()
        view.widgetGrid.stretch("1", by: Self.step.scaled(0, 2))
        #expect(view.widgetGrid.trial == ["1": .init(columns: 1, rows: 2)])
        view.widgetGrid.stretch("1", by: Self.step.scaled(0, 1))
        #expect(view.widgetGrid.trial == ["1": .init(columns: 1, rows: 2)])
        view.widgetGrid.stretch("1", by: Self.step.scaled(2, 2))
        #expect(view.widgetGrid.trial == ["1": .init(columns: 1, rows: 2)])
        view.widgets = (1...18).map(numbered)
        #expect(view.widgetGrid.fitted("1", adding: (1, 1)) == nil)
    }

    @Test func wideningStopsAtTheWidestSizeThatStillFits() {
        view.widgets = (1...17).map(numbered)
        view.editWidgets()
        view.widgetGrid.stretch("1", by: Self.step.scaled(2, 0))
        #expect(view.widgetGrid.trial == ["1": .init(columns: 2)])
        view.widgetGrid.stretch("1", by: Self.step.scaled(-1, 0))
        #expect(view.widgetGrid.trial.isEmpty)
        view.widgets = (1...18).map(numbered)
        #expect(view.widgetGrid.fitted("1", adding: (1, 0)) == nil)
    }

    @Test func commandEqualsAndMinusGrowAndShrinkTheSelectedWidget() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.editWidgets()
        view.selectWidget(0)
        #expect(view.performKeyEquivalent(with: try key(kVK_ANSI_Equal, "=", [.command])))
        #expect(edits == [.resize("1", .init(columns: 2))])
        #expect(view.performKeyEquivalent(with: try key(kVK_ANSI_Minus, "-", [.command])))
        #expect(edits.count == 1)
        view.widgetSizes = ["1": .init(columns: 3)]
        #expect(view.performKeyEquivalent(with: try key(kVK_ANSI_Minus, "-", [.command])))
        #expect(edits.last == .resize("1", .init(columns: 2)))
    }

    @Test func optionCommandEqualsAndMinusMakeTheSelectedWidgetTallerAndShorter() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.editWidgets()
        view.selectWidget(0)
        let grow = try key(kVK_ANSI_Equal, "=", [.command, .option])
        #expect(view.performKeyEquivalent(with: grow))
        #expect(edits == [.resize("1", .init(columns: 1, rows: 2))])
        view.widgetSizes = ["1": .init(columns: 1, rows: 2)]
        let shrink = try key(kVK_ANSI_Minus, "-", [.command, .option])
        #expect(view.performKeyEquivalent(with: shrink))
        #expect(edits.last == .resize("1", .init(columns: 1)))
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
        tile.mouseDragged(
            with: try mouse(.leftMouseDragged, at: moved(corner, by: Self.step.scaled(1, 0))))
        #expect(view.widgetGrid.trial == ["2": .init(columns: 2)])
        tile.mouseUp(with: try mouse(.leftMouseUp, at: corner))
        #expect(edits == [.resize("2", .init(columns: 2))])
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

    @Test func savedSizesStayBetweenTheWidgetsSmallestAndTheLargestItsSpotAllows() {
        let track = WidgetGrid.Track(title: "Song", artist: "Band", artwork: nil, isPlaying: true)
        view.widgets =
            [.init(id: "music", name: "Now Playing", track: track, action: "", spoken: "")]
            + (1...3).map(numbered)
        view.widgetSizes = [
            "music": .init(columns: 1), "1": .init(columns: 9, rows: 9), "2": .init(columns: 3),
            "3": .init(columns: 2, rows: 2),
        ]
        view.widgetSpots = ["3": .leftTop]
        #expect(
            view.widgetGrid.widgets.map(\.size) == [
                .init(columns: 2), .init(columns: 3, rows: 2), .init(columns: 3),
                .init(columns: 2, rows: 2),
            ])
    }

    @Test func everyTileResizesBothWaysExceptInTheStripWhichOnlyChangesWidth() {
        view.widgetSpots = ["2": .leftTop, "3": .aboveLeft]
        let axes = Dictionary(
            uniqueKeysWithValues: zip(view.widgetGrid.shown.map(\.id), view.widgetGrid.tiles)
                .map { ($0, $1.resizes) })
        #expect(axes["1"] == [.horizontal, .vertical])
        #expect(axes["3"] == [.horizontal, .vertical])
        #expect(axes["2"] == [.horizontal, .vertical])
        view.widgetSpots = [:]
        view.widgetLayout = .strip
        #expect(view.widgetGrid.tiles.allSatisfy { $0.resizes == [.horizontal] })
    }

    @Test func aRailTileResizesOnSquareUnitsAndAShelfTileStopsAtTwoRows() {
        view.widgetSpots = ["1": .leftTop, "2": .aboveLeft]
        view.editWidgets()
        #expect(view.widgetGrid.fitted("1", adding: (2, 2)) == .init(columns: 3, rows: 2))
        #expect(view.widgetGrid.fitted("1", adding: (-1, 1)) == .init(columns: 2, rows: 2))
        #expect(view.widgetGrid.fitted("1", adding: (-2, 0)) == .init(columns: 2, rows: 1))
        #expect(view.widgetGrid.fitted("2", adding: (0, 3)) == .init(columns: 1, rows: 2))
    }

    @Test func sizesAreSavedForAddedWidgetsAndGoWithARemovedOne() {
        let available = ["clock", "system"]
        var widgets = WidgetSettings()
        widgets.apply(.resize("clock", .init(columns: 3, rows: 2)), from: available)
        widgets.apply(.resize("weather", .init(columns: 2)), from: available)
        #expect(widgets.sizes(from: available) == ["clock": .init(columns: 3, rows: 2)])
        widgets.apply(.remove("clock"), from: available)
        widgets.apply(.add("clock"), from: available)
        #expect(widgets.sizes(from: available).isEmpty)
    }

    private func moved(_ point: NSPoint, by distance: CGSize) -> NSPoint {
        NSPoint(x: point.x + distance.width, y: point.y - distance.height)
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

extension CGSize {
    func scaled(_ across: CGFloat, _ down: CGFloat) -> CGSize {
        CGSize(width: width * across, height: height * down)
    }
}
