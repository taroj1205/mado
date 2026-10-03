import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetDropTests {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 548),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let view = LauncherView()
    private let widgets = ["clock", "weather", "battery", "system", "timer"].map(Self.widget)

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
        view.selectWidget(0)
        view.editWidgets()
        view.layoutSubtreeIfNeeded()
    }

    nonisolated private static func widget(_ id: String) -> WidgetGrid.Widget {
        .init(
            id: id, name: id.capitalized, value: id, detail: "", action: "Open \(id.capitalized)",
            spoken: id.capitalized)
    }

    @Test func draggingATileMovesItLiveAndDroppingSavesTheNewOrder() {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        #expect(view.dragWidget("battery", at: centre(of: 0), from: nil) == .move)
        #expect(ids == ["battery", "clock", "weather", "system", "timer"])
        #expect(view.widgetGrid.tiles.map(\.lifted) == [true, false, false, false, false])
        #expect(view.widgetGrid.tiles.map(\.selected) == [false, true, false, false, false])
        #expect(view.selectedWidget == 1)
        #expect(view.dropWidget("battery"))
        #expect(edits == [.move("battery", before: "clock")])
        #expect(ids == widgets.map(\.id))
        #expect(view.widgetGrid.tiles.map(\.lifted) == [false, false, false, false, false])
        #expect(view.selectedWidget == 0)
    }

    @Test func droppingAtTheEndMovesBeforeNothingAndLeavingPutsTheTilesBack() {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        #expect(view.dragWidget("clock", at: centre(of: 4), from: nil) == .move)
        #expect(ids == ["weather", "battery", "system", "timer", "clock"])
        view.endWidgetDrag()
        #expect(ids == widgets.map(\.id))
        #expect(view.dragWidget("clock", at: centre(of: 4), from: nil) == .move)
        #expect(view.dropWidget("clock"))
        #expect(edits == [.move("clock", before: nil)])
        #expect(view.dragWidget("weather", at: centre(of: 1), from: nil) == .move)
        #expect(view.dropWidget("weather"))
        #expect(edits == [.move("clock", before: nil)])
    }

    @Test func aGalleryCardShowsDropToAddAfterTheLastTileAndAddsItsWidget() {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        let card = WidgetGalleryCard(
            .init(
                id: "music", name: "Now Playing", summary: "Music controls", size: .wide,
                group: nil, symbol: "heart.fill", colour: .systemPink))
        let four = Array(widgets.prefix(4))
        view.widgets = four
        view.layoutSubtreeIfNeeded()
        let height = view.widgetGrid.frame.height
        #expect(view.dragWidget("music", at: centre(of: 0), from: card) == .copy)
        view.layoutSubtreeIfNeeded()
        let frame = view.widgetGrid.dropFrame.frame
        let tile = view.widgetGrid.tiles[3]
        #expect(!view.widgetGrid.dropFrame.isHidden)
        #expect(view.widgetGrid.dropFrame.label.stringValue == "Drop to add")
        #expect(abs(frame.minX - tile.frame.maxX - 8) < 1)
        #expect(abs(frame.width - (2 * tile.frame.width + 8)) < 1)
        #expect(view.widgetGrid.frame.height == height)
        #expect(ids == four.map(\.id))
        #expect(view.dropWidget("music"))
        #expect(edits == [.add("music")])
        #expect(view.widgetGrid.dropFrame.isHidden)
        #expect(view.dragWidget("notes", at: centre(of: 0), from: nil) == .copy)
        view.widgets = widgets + [Self.widget("calendar")]
        view.layoutSubtreeIfNeeded()
        #expect(view.widgetGrid.frame.height == height + 78 + 8)
        view.endWidgetDrag()
        #expect(view.widgetGrid.dropFrame.isHidden)
    }

    @Test func dropsAreRefusedOutsideEditModeOrWithoutAWidget() {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        #expect(view.dragWidget(nil, at: centre(of: 0), from: nil).isEmpty)
        #expect(!view.dropWidget(nil))
        view.finishEditingWidgets()
        #expect(view.dragWidget("music", at: centre(of: 0), from: nil).isEmpty)
        #expect(!view.dropWidget("music"))
        #expect(view.widgetGrid.dropFrame.isHidden)
        #expect(edits.isEmpty)
    }

    private func centre(of index: Int) -> NSPoint {
        let tile = view.widgetGrid.tiles[index]
        return tile.convert(NSPoint(x: tile.bounds.midX, y: tile.bounds.midY), to: nil)
    }
}
