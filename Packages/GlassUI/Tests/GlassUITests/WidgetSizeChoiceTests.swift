import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetSizeChoiceTests {
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

    @Test func theTileFollowsThePointerPastTheLargestSizeButOnlyStretchesALittle() throws {
        view.editWidgets()
        view.selectWidget(0)
        view.layoutSubtreeIfNeeded()
        let tile = view.widgetGrid.tiles[0]
        let handle = tile.convert(
            NSPoint(x: tile.resizer.frame.midX, y: tile.resizer.frame.midY), to: nil)
        tile.mouseDown(with: try mouse(.leftMouseDown, at: handle))
        tile.mouseDragged(
            with: try mouse(.leftMouseDragged, at: moved(handle, by: Self.step.scaled(9, 0))))
        view.layoutSubtreeIfNeeded()
        let grid = view.widgetGrid
        #expect(grid.trial == ["1": .init(columns: 3)])
        let widest = grid.guide.frame.width
        #expect(grid.tiles[0].frame.width > widest)
        #expect(grid.tiles[0].frame.width < widest + 24)
        tile.mouseUp(with: try mouse(.leftMouseUp, at: handle))
    }

    @Test func lettingGoSettlesTheTileOnItsOutlineAndHidesTheGuide() throws {
        view.editWidgets()
        view.selectWidget(0)
        view.layoutSubtreeIfNeeded()
        let tile = view.widgetGrid.tiles[0]
        let narrow = tile.frame
        let handle = tile.convert(
            NSPoint(x: tile.resizer.frame.midX, y: tile.resizer.frame.midY), to: nil)
        tile.mouseDown(with: try mouse(.leftMouseDown, at: handle))
        tile.mouseDragged(
            with: try mouse(.leftMouseDragged, at: moved(handle, by: Self.step.scaled(0.3, 0))))
        view.layoutSubtreeIfNeeded()
        #expect(view.widgetGrid.tiles[0].frame.width > narrow.width)
        tile.mouseUp(with: try mouse(.leftMouseUp, at: handle))
        #expect(view.widgetGrid.settling?.id == "1")
        view.layoutSubtreeIfNeeded()
        #expect(view.widgetGrid.settling == nil)
        #expect(view.widgetGrid.tiles[0].frame == narrow)
        #expect(view.widgetGrid.guide.isHidden && view.widgetGrid.sizeLabel.isHidden)
    }

    @Test func dragThroughTheSameSizeKeepsTheBarsButtonsInsteadOfRebuildingThem() {
        view.editWidgets()
        view.selectWidget(0)
        view.layoutSubtreeIfNeeded()
        let before = view.editBar.sizes.buttons
        #expect(before.count == 3)
        view.widgetGrid.stretch("1", by: Self.step.scaled(0.1, 0))
        view.widgetGrid.stretch("1", by: Self.step.scaled(0.2, 0))
        view.showWidgetTools()
        #expect(
            view.editBar.sizes.buttons.map(ObjectIdentifier.init)
                == before.map(ObjectIdentifier.init))
    }

    @Test func eachTileOffersTheNamedSizesInsideItsOwnRange() {
        let grid = view.widgetGrid
        #expect(grid.options(for: "1") == [.small, .wide, .large])
        view.widgetSpots = ["1": .leftTop, "2": .aboveLeft]
        #expect(grid.options(for: "1") == [.init(columns: 3), .init(columns: 3, rows: 2)])
        #expect(grid.options(for: "2") == [.small, .wide, .large])
        #expect(grid.options(for: "missing").isEmpty)
    }

    @Test func aSizeThatWouldNotFitIsNotOffered() {
        view.widgets = (1...17).map(numbered)
        #expect(view.widgetGrid.options(for: "1") == [.small, .wide])
    }

    @Test func theInspectorListsTheSizesThatFitAndPressingOneResizes() {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.editWidgets()
        view.selectWidget(0)
        view.layoutSubtreeIfNeeded()
        let sizes = view.editBar.sizes
        #expect(!sizes.isHidden)
        #expect(sizes.buttons.map(\.label.stringValue) == ["Small", "Medium", "Large"])
        sizes.buttons[0].onPress?()
        #expect(edits.isEmpty)
        sizes.buttons[2].onPress?()
        #expect(edits == [.resize("1", .init(columns: 2, rows: 2))])
    }

    @Test func aRailTileOffersRowsInTheInspector() {
        view.widgetSpots = ["1": .leftTop]
        view.editWidgets()
        let index = view.widgetGrid.shown.firstIndex { $0.id == "1" }
        view.selectWidget(index)
        view.layoutSubtreeIfNeeded()
        #expect(view.editBar.sizes.buttons.map(\.label.stringValue) == ["1 row", "2 rows"])
    }

    @Test func theInspectorHidesTheSizesWhenThereIsNothingToChooseBetween() {
        view.widgets = (1...18).map(numbered)
        view.editWidgets()
        view.selectWidget(0)
        view.layoutSubtreeIfNeeded()
        #expect(view.editBar.sizes.isHidden)
    }

    @Test func aNoteMovesAboveTheInspectorWhenTheyDoNotFitSideBySide() {
        view.editWidgets()
        view.selectWidget(0)
        view.report(.resize("1", .init(columns: 2, rows: 2)))
        view.layoutSubtreeIfNeeded()
        #expect(view.editBar.orientation == .vertical)
        #expect(view.editBar.notice.frame.minY > view.editBar.inspector.frame.maxY - 1)
        #expect(view.editBar.frame.maxX <= view.bounds.maxX)
    }

    private func moved(_ point: NSPoint, by distance: CGSize) -> NSPoint {
        NSPoint(x: point.x + distance.width, y: point.y - distance.height)
    }

    private func mouse(_ type: NSEvent.EventType, at point: NSPoint) throws -> NSEvent {
        try #require(
            NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1,
                pressure: 1))
    }

    private func numbered(_ number: Int) -> WidgetGrid.Widget {
        .init(
            id: "\(number)", name: "Widget \(number)", value: "\(number)", detail: "",
            action: "Open \(number)", spoken: "Widget \(number)")
    }
}
