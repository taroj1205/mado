import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetGroupTests {
    private static let frame = NSRect(x: 400, y: 200, width: 760, height: 476)

    private let panel = NSPanel(
        contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
        defer: false)
    private let view = LauncherView()

    private var ids: [String] { view.widgetGrid.shown.map(\.id) }

    private var passThrough: [String] {
        zip(view.widgetGrid.floats, view.widgetGrid.placed)
            .filter(\.0.ignoresMouseEvents)
            .map(\.1.widget.id)
    }

    init() {
        panel.contentView = view
        view.widgets = (1...7).map(numbered)
        panel.makeFirstResponder(view.field)
        view.layoutSubtreeIfNeeded()
    }

    @Test func shiftClickingPicksWidgetsAndGroupGathersThemAtTheFirstOneOutside() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.widgetSpots = ["2": .leftTop, "3": .rightTop]
        view.editWidgets()
        select("2")
        let first = view.widgetGrid.tiles[0]
        first.mouseDown(with: try click(first, [.shift]))
        #expect(view.chosenWidgets == ["2", "1"])
        #expect(
            view.widgetGrid.tiles.map(\.selected) == [true] + Array(repeating: false, count: 4)
                + [true, false])
        #expect(view.editBar.name.stringValue == "2 widgets")
        #expect(!view.editBar.group.isHidden)
        #expect(view.editBar.move.isHidden && view.editBar.remove.isHidden)
        view.editBar.group.onPress?()
        #expect(edits == [.group(["1", "2"], .leftTop, before: nil)])
        #expect(view.editBar.hint.stringValue == "2 widgets grouped · Left · Top")
        #expect(view.chosenWidgets == ["2"])
    }

    @Test func shiftClickingAPickedWidgetAgainDropsItAndAPlainClickKeepsOnlyThatOne() {
        view.editWidgets()
        select("1")
        view.extendWidgetSelection(1)
        view.extendWidgetSelection(2)
        #expect(view.chosenWidgets == ["1", "2", "3"])
        view.extendWidgetSelection(1)
        #expect(view.chosenWidgets == ["1", "3"])
        view.extendWidgetSelection(0)
        #expect(view.chosenWidgets == ["3"])
        #expect(view.selectedWidget == 2)
        view.extendWidgetSelection(4)
        view.selectWidget(4)
        #expect(view.chosenWidgets == ["5"])
        #expect(view.widgetGrid.tiles.filter(\.selected).count == 1)
    }

    @Test func groupingOnlyPanelWidgetsAsksForOneOutsideFirst() {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.editWidgets()
        select("1")
        view.extendWidgetSelection(1)
        view.groupWidgets()
        #expect(edits.isEmpty)
        #expect(view.editBar.hint.stringValue == "Move one of them out of the panel to group them")
    }

    @Test func shiftArrowsGrowTheSelectionAndCommandGGroupsIt() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.widgetSpots = ["1": .leftTop, "2": .leftMiddle]
        view.editWidgets()
        select("1")
        #expect(view.handle(try key(kVK_DownArrow, "\u{F701}", [.shift])))
        #expect(view.chosenWidgets == ["1", "2"])
        #expect(view.handle(try key(kVK_UpArrow, "\u{F700}", [.shift])))
        #expect(view.chosenWidgets == ["1"])
        #expect(view.handle(try key(kVK_DownArrow, "\u{F701}", [.shift])))
        #expect(view.performKeyEquivalent(with: try key(kVK_ANSI_G, "g", [.command])))
        #expect(edits == [.group(["1", "2"], .leftTop, before: nil)])
    }

    @Test func ungroupingGivesEachWidgetTheSpotItAlreadyShowsAt() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.widgetSpots = [
            "1": .leftTop, "2": .leftTop, "3": .above(column: 1, row: 0),
            "4": .above(column: 1, row: 0),
        ]
        view.editWidgets()
        select("1")
        #expect(!view.editBar.ungroup.isHidden)
        #expect(view.editBar.group.isHidden)
        #expect(view.performKeyEquivalent(with: try key(kVK_ANSI_G, "G", [.command, .shift])))
        #expect(edits == [.spread(["1": .leftTop, "2": .beside(.left, row: 1)])])
        #expect(view.editBar.hint.stringValue == "Ungrouped")
        #expect(view.chosenWidgets == ["1"])
        select("3")
        view.editBar.ungroup.onPress?()
        #expect(
            edits.last
                == .spread(["3": .above(column: 1, row: 0), "4": .aboveCentre]))
        select("5")
        #expect(view.editBar.ungroup.isHidden)
    }

    @Test func draggingOneWidgetOfAGroupMovesTheWholeGroup() {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.widgetSpots = ["1": .leftTop, "2": .leftTop, "3": .rightBottom]
        view.editWidgets()
        select("2")
        start(dragging: "2")
        #expect(view.dragWidget("2", at: window(CGPoint(x: 1_290, y: 548)), from: nil) == .move)
        #expect(view.widgetGrid.moving == .rightTop)
        #expect(view.widgetGrid.spot(of: numbered(1)) == .rightTop)
        #expect(view.widgetGrid.rails.board.model.ghost?.spot == .rightTop)
        #expect(passThrough == ["1", "2"])
        #expect(view.dropWidget("2"))
        #expect(edits == [.group(["1", "2"], .rightTop, before: nil)])
        #expect(view.editBar.hint.stringValue == "Group moved · Right · Top")
        #expect(view.chosenWidgets == ["2"])
        #expect(passThrough.isEmpty)
    }

    @Test func aLongNoteBesideTheGroupToolsTruncatesInsteadOfWideningTheLauncher() {
        view.widgetSpots = ["1": .above(column: 3, row: 1), "2": .above(column: 3, row: 1)]
        view.widgets = (1...7).map { number in
            .init(
                id: "\(number)", name: "Widget with a long name \(number)", value: "", detail: "",
                action: "Open \(number)", spoken: "Widget \(number)")
        }
        view.editWidgets()
        select("1")
        view.report(.group(["1", "2"], .above(column: 3, row: 1), before: nil))
        panel.layoutIfNeeded()
        #expect(!view.editBar.ungroup.isHidden && !view.editBar.notice.isHidden)
        #expect(panel.frame.width == Self.frame.width)
        #expect(view.editBar.frame.maxX <= view.bounds.maxX)
    }

    @Test func aGroupDraggedIntoThePanelLandsTogetherBeforeTheTileUnderIt() {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.widgetSpots = ["1": .leftTop, "2": .leftTop]
        start(dragging: "1")
        let frames = view.widgetGrid.tileFrames(in: panel)
        #expect(
            view.dragWidget("1", at: NSPoint(x: frames[0].midX, y: frames[0].midY), from: nil)
                == .move)
        #expect(ids == (1...7).map(String.init))
        #expect(view.dropWidget("1"))
        #expect(edits == [.group(["1", "2"], .panel, before: "3")])
    }

    @Test func optionArrowsStepOneSlotAndSkipSlotsThatAreTaken() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.widgetSpots = ["1": .above(column: 3, row: 0), "2": .aboveCentre]
        view.editWidgets()
        select("1")
        #expect(view.handle(try key(kVK_LeftArrow, "\u{F702}", [.option])))
        #expect(edits == [.place("1", .above(column: 1, row: 0), before: nil)])
        #expect(view.handle(try key(kVK_UpArrow, "\u{F700}", [.option])))
        #expect(edits.last == .place("1", .above(column: 3, row: 1), before: nil))
    }

    @Test func thePickerMarksTheNearestNamedSpotAndReturnLeavesAFineSpotAlone() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.widgetSpots = ["1": .beside(.left, row: 1)]
        view.editWidgets()
        select("1")
        view.editBar.move.onPress?()
        let picker = try #require(view.spotPicker)
        #expect(picker.marks.filter(\.isOn).map(\.spot) == [.leftTop])
        #expect(picker.label.stringValue == "Left · Upper")
        try press(kVK_Return, "\r")
        #expect(edits.isEmpty)
        #expect(view.spotPicker == nil)
    }

    @Test func fineSpotsHaveNamesBesidesTheNineNamedOnes() {
        #expect(WidgetGrid.Spot.above(column: 3, row: 1).title == "Above · Column 4, Row 2")
        #expect(WidgetGrid.Spot.above(column: 0, row: 2).title == "Above · Left, Row 3")
        #expect(WidgetGrid.Spot.beside(.right, row: 3).title == "Right · Lower")
        #expect(WidgetGrid.Spot.above(column: 4, row: 0).preset == .aboveRight)
        #expect(WidgetGrid.Spot.beside(.left, row: 1).preset == .leftTop)
    }

    private func select(_ id: String) {
        view.selectWidget(ids.firstIndex(of: id))
    }

    private func start(dragging id: String) {
        view.widgetGrid.tiles[ids.firstIndex(of: id) ?? 0].onDragStart?()
    }

    private func window(_ screen: CGPoint) -> NSPoint {
        panel.convertPoint(fromScreen: screen)
    }

    private func press(_ keyCode: Int, _ characters: String) throws {
        let event = try key(keyCode, characters)
        if !view.handle(event) {
            panel.sendEvent(event)
        }
    }

    private func click(_ tile: WidgetTile, _ flags: NSEvent.ModifierFlags) throws -> NSEvent {
        let point = tile.convert(NSPoint(x: tile.bounds.midX, y: tile.bounds.midY), to: nil)
        return try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown, location: point, modifierFlags: flags, timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1,
                pressure: 1))
    }

    private func key(
        _ keyCode: Int, _ characters: String, _ modifiers: NSEvent.ModifierFlags = []
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
