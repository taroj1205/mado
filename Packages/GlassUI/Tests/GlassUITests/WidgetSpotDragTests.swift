import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetSpotDragTests {
    private static let frame = NSRect(x: 400, y: 200, width: 760, height: 476)

    private let panel = NSPanel(
        contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
        defer: false)
    private let view = LauncherView()

    private var ids: [String] { view.widgetGrid.shown.map(\.id) }

    init() {
        panel.contentView = view
        view.widgets = (1...7).map(numbered)
        panel.makeFirstResponder(view.field)
        view.layoutSubtreeIfNeeded()
    }

    @Test func theNearestSpotIsThePanelInsideItAndAnAnchorWithinReachOutside() {
        let launcher = Self.frame
        #expect(WidgetGrid.nearestSpot(to: CGPoint(x: 500, y: 300), beside: launcher) == .panel)
        #expect(
            WidgetGrid.nearestSpot(to: CGPoint(x: 290, y: 437), beside: launcher) == .leftMiddle)
        #expect(
            WidgetGrid.nearestSpot(to: CGPoint(x: 1_290, y: 640), beside: launcher) == .rightTop)
        #expect(
            WidgetGrid.nearestSpot(to: CGPoint(x: launcher.midX, y: 740), beside: launcher)
                == .aboveCentre)
        #expect(WidgetGrid.nearestSpot(to: CGPoint(x: 100, y: 950), beside: launcher) == nil)
    }

    @Test func commandDraggingOntoAnEmptyRailMovesTheWidgetThere() {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        start(dragging: 1)
        #expect(view.dragWidget("2", at: window(CGPoint(x: 290, y: 437)), from: nil) == .move)
        #expect(ids == ["1", "3", "4", "5", "6", "7", "2"])
        #expect(view.widgetGrid.floats.count == 1)
        let board = view.widgetGrid.rails.board
        #expect(board.model.hot == .left)
        #expect(board.model.ghost?.spot == .leftMiddle)
        #expect(board.label.title == "Left · Middle")
        #expect(view.dropWidget("2"))
        #expect(edits == [.place("2", .leftMiddle, before: nil)])
        #expect(ids == (1...7).map(String.init))
    }

    @Test func aSpotWithNoRoomRefusesTheDropAndTheWidgetStays() {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.widgetSpots = Dictionary(uniqueKeysWithValues: (1...5).map { ("\($0)", .rightTop) })
        start(dragging: 0)
        #expect(view.dragWidget("6", at: window(CGPoint(x: 1_290, y: 640)), from: nil).isEmpty)
        #expect(view.widgetGrid.refused == .rightTop)
        #expect(ids == ["6", "7", "1", "2", "3", "4", "5"])
        #expect(view.widgetGrid.rails.board.label.title == "No room — try another spot")
        #expect(!view.dropWidget("6"))
        #expect(edits.isEmpty)
        #expect(view.widgetGrid.refused == nil)
    }

    @Test func farFromEverySpotTheDragKeepsItsLastPreviewButCannotDrop() {
        start(dragging: 1)
        #expect(view.dragWidget("2", at: window(CGPoint(x: 290, y: 437)), from: nil) == .move)
        #expect(view.dragWidget("2", at: window(CGPoint(x: 100, y: 950)), from: nil).isEmpty)
        #expect(view.widgetGrid.spot(of: numbered(2)) == .leftMiddle)
    }

    @Test func thePreviewedSpotStaysDroppableAroundItsGhost() {
        start(dragging: 1)
        #expect(view.dragWidget("2", at: window(CGPoint(x: 290, y: 437)), from: nil) == .move)
        #expect(view.dragWidget("2", at: window(CGPoint(x: 270, y: 530)), from: nil) == .move)
        #expect(view.widgetGrid.moving == .leftMiddle)
    }

    @Test func aFullSpotAfterAGoodOneSaysThereIsNoRoom() {
        view.widgetSpots = Dictionary(uniqueKeysWithValues: (1...5).map { ("\($0)", .rightTop) })
        start(dragging: 0)
        #expect(view.dragWidget("6", at: window(CGPoint(x: 290, y: 437)), from: nil) == .move)
        #expect(view.dragWidget("6", at: window(CGPoint(x: 1_290, y: 640)), from: nil).isEmpty)
        #expect(view.widgetGrid.rails.board.label.title == "No room — try another spot")
    }

    @Test func whileEditingBlankSpaceFarFromEverySpotCannotTakeTheDrop() {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.editWidgets()
        start(dragging: 1)
        #expect(view.dragWidget("2", at: window(CGPoint(x: 290, y: 437)), from: nil) == .move)
        #expect(view.dragWidget("2", at: window(CGPoint(x: 100, y: 950)), from: nil).isEmpty)
        view.endWidgetDrag()
        #expect(edits.isEmpty)
    }

    @Test func aGalleryCardCanLandOnAnySpotAroundThePanel() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.widgetCatalogue = [.init(id: "new", name: "New", summary: "", group: .today)]
        view.editWidgets()
        let card = try #require(view.gallery.cards.first)
        #expect(view.dragWidget("new", at: window(CGPoint(x: 290, y: 437)), from: card) == .copy)
        #expect(ids.last == "new")
        #expect(view.widgetGrid.floats.count == 1)
        #expect(view.widgetGrid.rails.board.model.ghost?.spot == .leftMiddle)
        #expect(view.dropWidget("new"))
        #expect(edits == [.place("new", .leftMiddle, before: nil)])
        #expect(view.widgetGrid.floats.isEmpty)
    }

    @Test func comingBackToItsOwnSpotPutsTheWidgetBackInPlace() {
        start(dragging: 1)
        #expect(view.dragWidget("2", at: window(CGPoint(x: 290, y: 437)), from: nil) == .move)
        #expect(view.dragWidget("2", at: window(CGPoint(x: 500, y: 300)), from: nil).isEmpty)
        #expect(view.widgetGrid.moving == nil)
        #expect(ids == (1...7).map(String.init))
    }

    @Test func placingKeepsThePresetSpotsOfEveryOtherWidget() {
        let available = ["clock", "system", "battery"]
        var widgets = WidgetSettings()
        widgets.keep(widgets.spots(.around, from: available))
        widgets.apply(.place("clock", .aboveCentre, before: nil), from: available)
        #expect(widgets.added(from: available) == ["system", "battery", "clock"])
        #expect(
            widgets.spots(.custom, from: available)
                == ["clock": .aboveCentre, "system": .leftTop, "battery": .rightTop])
    }

    @Test func editingKeepsEveryWidgetAtItsSpotAndShowsTheRails() {
        view.widgetLayout = .strip
        view.widgetSpots = WidgetSettings().spots(.above, from: (1...7).map(String.init))
        #expect(!view.widgetGrid.rails.isVisible)
        view.selectWidget(0)
        view.editWidgets()
        #expect(view.widgetGrid.floats.count == 7)
        let editing = view.widgetGrid.tiles.map(\.editing)
        #expect(!editing.contains(false))
        #expect(view.widgetGrid.rails.parent === panel)
        #expect(view.widgetGrid.rails.board.model.pucks.count == 8)
        #expect(!view.widgetGrid.dock.isHidden)
        #expect(view.widgetGrid.frame.height > 0)
        let float = view.widgetGrid.floats[0]
        let tile = view.widgetGrid.tiles[0]
        #expect(float.contentView is WidgetFloatFrame)
        #expect(unsafe tile.remove.superview === float.contentView)
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        tile.remove.onPress?()
        #expect(edits == [.remove("1")])
        view.finishEditingWidgets()
        #expect(!view.widgetGrid.rails.isVisible)
        #expect(view.widgetGrid.dock.isHidden)
        view.widgetSpots = [:]
        #expect(view.widgetGrid.shown.count == 6)
    }

    @Test func aFullStripRefusesAWidgetMovingIntoThePanel() {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.widgetLayout = .strip
        view.widgetSpots = ["7": .leftTop]
        #expect(!view.widgetGrid.accepts("7", at: .panel, before: nil))
        start(dragging: 6)
        #expect(view.dragWidget("7", at: window(CGPoint(x: 500, y: 300)), from: nil).isEmpty)
        #expect(view.widgetGrid.refused == .panel)
        #expect(!view.dropWidget("7"))
        #expect(edits.isEmpty)
        view.widgetSpots = ["6": .leftTop, "7": .leftTop]
        #expect(view.widgetGrid.accepts("7", at: .panel, before: nil))
    }

    private func start(dragging index: Int) {
        view.widgetGrid.tiles[index].onDragStart?()
    }

    private func window(_ screen: CGPoint) -> NSPoint {
        panel.convertPoint(fromScreen: screen)
    }

    private func numbered(_ number: Int) -> WidgetGrid.Widget {
        .init(
            id: "\(number)", name: "Widget \(number)", value: "\(number)", detail: "",
            action: "Open \(number)", spoken: "Widget \(number)")
    }
}
