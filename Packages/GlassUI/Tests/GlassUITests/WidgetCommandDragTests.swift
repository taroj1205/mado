import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetCommandDragTests {
    private let panel = NSPanel(
        contentRect: NSRect(x: 100, y: 100, width: 760, height: 476),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let view = LauncherView()
    private let widgets = ["clock", "weather", "battery", "system"].map { id in
        WidgetGrid.Widget(
            id: id, name: id.capitalized, value: id, detail: "", action: "Open \(id.capitalized)",
            spoken: id.capitalized)
    }

    private var ids: [String] { view.widgetGrid.shown.map(\.id) }

    init() {
        panel.contentView = view
        view.results.sections = [
            .init(
                title: "Commands",
                items: [
                    .init(
                        id: "Safari", title: "Safari", subtitle: "", kind: "Command",
                        symbol: "star", action: "Run Command")
                ])
        ]
        view.widgets = widgets
        panel.makeFirstResponder(view.field)
        view.layoutSubtreeIfNeeded()
    }

    @Test func commandPressingATileStartsADragInsteadOfRunningIt() throws {
        var ran: [String] = []
        view.onWidget = { ran.append($0.id) }
        let tile = view.widgetGrid.tiles[1]
        tile.mouseDown(with: try click(tile, [.command]))
        #expect(ran.isEmpty)
        #expect(tile.dragStart != nil)
        tile.mouseUp(with: try click(tile, [.command]))
        #expect(tile.dragStart == nil)
        tile.mouseDown(with: try click(tile, []))
        #expect(ran == ["weather"])
        #expect(tile.dragStart == nil)
    }

    @Test func commandDraggingReordersTheInlineGridWithoutEditMode() {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        #expect(view.dragWidget("battery", at: centre(of: 0), from: nil) == .move)
        #expect(ids == ["battery", "clock", "weather", "system"])
        #expect(view.dropWidget("battery"))
        #expect(edits == [.move("battery", before: "clock")])
        #expect(ids == widgets.map(\.id))
        #expect(!view.editingWidgets)
        #expect(view.dragWidget("clock", at: centre(of: 0), from: nil) == .move)
        #expect(view.dropWidget("clock"))
        #expect(edits == [.move("battery", before: "clock")])
    }

    @Test func outsideEditModeADropOffTheTilesLandsWhereTheSlotShows() {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        #expect(view.dragWidget("battery", at: centre(of: 0), from: nil) == .move)
        let list = view.results.convert(
            NSPoint(x: view.results.bounds.midX, y: view.results.bounds.midY), to: nil)
        #expect(view.dragWidget("battery", at: list, from: nil) == .move)
        #expect(ids == ["battery", "clock", "weather", "system"])
        #expect(view.dropWidget("battery"))
        #expect(edits == [.move("battery", before: "clock")])
    }

    @Test func droppingOnTheLastStripTileKeepsTheWidgetInTheStrip() {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        let seven = (1...7).map { number in
            WidgetGrid.Widget(
                id: "\(number)", name: "\(number)", value: "\(number)", detail: "",
                action: "Open \(number)", spoken: "\(number)")
        }
        view.widgets = seven
        view.widgetLayout = .strip
        view.layoutSubtreeIfNeeded()
        #expect(ids == ["1", "2", "3", "4", "5", "6"])
        #expect(view.dragWidget("1", at: centre(of: 5), from: nil) == .move)
        #expect(ids == ["2", "3", "4", "5", "6", "1"])
        #expect(view.dropWidget("1"))
        #expect(edits == [.move("1", before: "7")])
    }

    @Test func outsideEditModeOnlyShownWidgetsCanBeDropped() {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        #expect(view.dragWidget("music", at: centre(of: 0), from: nil).isEmpty)
        #expect(!view.dropWidget("music"))
        #expect(edits.isEmpty)
    }

    @Test func floatingTilesTakeTheDragAndReorderWithinTheirSpot() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        arrange(.around)
        let accepting = view.widgetGrid.tiles.map(\.registeredDraggedTypes)
        #expect(accepting.allSatisfy { $0 == [WidgetGrid.dragType] })
        let target = view.widgetGrid.floats[3].frame
        let tile = view.widgetGrid.tiles[2]
        let over = try #require(tile.onDrag)
        #expect(over("battery", NSPoint(x: target.midX, y: target.midY), nil) == .move)
        #expect(ids == ["clock", "weather", "system", "battery"])
        #expect(view.widgetGrid.floats[3].frame == target)
        #expect(view.widgetGrid.tiles.map(\.lifted) == [false, false, false, true])
        #expect(tile.onDrop?("battery") == true)
        #expect(edits == [.move("battery", before: nil)])
    }

    @Test func aTileDraggedOntoAnotherSpotMovesThereBeforeTheTileUnderIt() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        arrange(.around)
        let other = view.widgetGrid.floats[2].frame
        let tile = view.widgetGrid.tiles[0]
        tile.onDragStart?()
        #expect(view.widgetGrid.rails.parent === panel)
        let over = try #require(tile.onDrag)
        #expect(over("clock", NSPoint(x: other.midX, y: other.midY), nil) == .move)
        #expect(ids == ["weather", "clock", "battery", "system"])
        #expect(view.widgetGrid.spot(of: widgets[0]) == .rightTop)
        #expect(view.widgetGrid.rails.board.model.ghost?.spot == .rightTop)
        #expect(view.widgetGrid.rails.board.label.title == "Right · Top")
        #expect(tile.onDrop?("clock") == true)
        #expect(edits == [.place("clock", .rightTop, before: "battery")])
        #expect(!view.widgetGrid.rails.isVisible)
    }

    @Test func aDragThatEndsNowherePutsTheFloatsBack() {
        arrange(.above)
        let target = view.widgetGrid.floats[3].frame
        let tile = view.widgetGrid.tiles[0]
        #expect(tile.onDrag?("clock", NSPoint(x: target.midX, y: target.midY), nil) == .move)
        #expect(ids == ["weather", "battery", "system", "clock"])
        tile.onDragEnd?()
        #expect(ids == widgets.map(\.id))
        #expect(view.widgetGrid.tiles.allSatisfy { !$0.lifted })
    }

    @Test func inlineTilesLeaveTheDropToTheLauncher() {
        let grid = view.widgetGrid.tiles.allSatisfy(\.registeredDraggedTypes.isEmpty)
        view.widgetLayout = .strip
        let strip = view.widgetGrid.tiles.allSatisfy(\.registeredDraggedTypes.isEmpty)
        #expect(grid && strip)
    }

    private func centre(of index: Int) -> NSPoint {
        let tile = view.widgetGrid.tiles[index]
        return tile.convert(NSPoint(x: tile.bounds.midX, y: tile.bounds.midY), to: nil)
    }

    private func click(_ tile: WidgetTile, _ flags: NSEvent.ModifierFlags) throws -> NSEvent {
        let point = tile.convert(NSPoint(x: tile.bounds.midX, y: tile.bounds.midY), to: nil)
        return try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown, location: point, modifierFlags: flags, timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1,
                pressure: 1))
    }

    private func arrange(_ arrangement: WidgetSettings.Arrangement) {
        view.widgetSpots = WidgetSettings().spots(arrangement, from: view.widgets.map(\.id))
    }
}
