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
        #expect(view.selectedWidget == 2)
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

    @Test func aGalleryCardBecomesALiveTileWhereItWouldLandAndDropsThere() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.widgetCatalogue = [
            .init(
                id: "music", name: "Now Playing", summary: "Music controls", group: .media,
                isWide: true)
        ]
        let card = try #require(view.gallery.cards.first)
        let four = Array(widgets.prefix(4))
        view.widgets = four
        view.layoutSubtreeIfNeeded()
        #expect(view.dragWidget("music", at: centre(of: 1), from: card) == .copy)
        #expect(ids == ["clock", "music", "weather", "battery", "system"])
        #expect(view.widgetGrid.tiles[1].lifted)
        #expect(view.widgetGrid.shown[1].isWide)
        #expect(view.widgetGrid.moving == .panel)
        #expect(view.dropWidget("music"))
        #expect(edits == [.place("music", .panel, before: "weather")])
        #expect(view.widgetGrid.incoming == nil)
        #expect(ids == four.map(\.id))
        #expect(view.dragWidget("notes", at: centre(of: 0), from: nil).isEmpty)
        #expect(view.dragWidget("notes", at: centre(of: 0), from: card).isEmpty)
    }

    @Test func aGalleryCardLetGoFarFromEverySpotAddsNothing() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.widgetCatalogue = [.init(id: "notes", name: "Notes", summary: "", group: .text)]
        let card = try #require(view.gallery.cards.first)
        #expect(view.dragWidget("notes", at: NSPoint(x: -900, y: -900), from: card).isEmpty)
        #expect(!ids.contains("notes"))
        #expect(!view.dropWidget("notes"))
        #expect(edits.isEmpty)
    }

    @Test func dropsAreRefusedOutsideEditModeOrWithoutAWidget() {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        #expect(view.dragWidget(nil, at: centre(of: 0), from: nil).isEmpty)
        #expect(!view.dropWidget(nil))
        view.finishEditingWidgets()
        #expect(view.dragWidget("music", at: centre(of: 0), from: nil).isEmpty)
        #expect(!view.dropWidget("music"))
        #expect(edits.isEmpty)
    }

    private func centre(of index: Int) -> NSPoint {
        let tile = view.widgetGrid.tiles[index]
        return tile.convert(NSPoint(x: tile.bounds.midX, y: tile.bounds.midY), to: nil)
    }
}
