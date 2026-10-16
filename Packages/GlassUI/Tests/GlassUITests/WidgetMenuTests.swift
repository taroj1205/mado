import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetMenuTests {
    private let rig = WidgetPointerRig()

    private var view: LauncherView { rig.view }
    private var tiles: [WidgetTile] { rig.tiles }
    private var titles: [String] { rig.titles }

    @Test func rightClickingAWidgetOpensItsMenu() throws {
        tiles[1].rightMouseDown(with: try rig.event(.rightMouseDown, on: tiles[1]))
        view.layoutSubtreeIfNeeded()
        let menu = try #require(view.widgetMenu)
        #expect(
            titles == [
                "Open Weather", "Move to…", "Size", "Edit Widgets", "Add Widgets…",
                "Remove Weather",
            ])
        #expect(menu.rows[0].keycaps.map(\.name.stringValue) == ["↵"])
        #expect(menu.rows[1].detail.stringValue == "In the panel")
        #expect(unsafe menu.rows[1].chevron.superview != nil)
        #expect(menu.rows[2].detail.stringValue == "Small · 1 × 1")
        #expect(menu.rows[5].isDestructive)
        #expect(view.selectedWidget == 1)
        #expect(tiles.map(\.menuOpen) == [false, true, false])
        #expect(view.popupBounds.contains(menu.panel.frame))
        #expect(menu.panel.frame.width == WidgetMenu.width)
    }

    @Test func theMenuFloatsAboveTheLauncherInAWindowOfItsOwn() throws {
        try rig.open(1)
        let menu = try #require(view.widgetMenu)
        #expect(menu.panel.parent === rig.panel)
        #expect(unsafe menu.glass.window === menu.panel)
        #expect(!menu.panel.ignoresMouseEvents)
        #expect(!menu.panel.canBecomeKey)
        menu.glass.layoutSubtreeIfNeeded()
        #expect(menu.panel.frame.size == menu.popupSize)
        let rows = menu.rows.map { menu.glass.convert($0.bounds, from: $0) }
        #expect(rows.allSatisfy { menu.glass.bounds.contains($0) })
        view.closeWidgetMenu()
        #expect(menu.panel.parent == nil)
        #expect(!menu.panel.isVisible)
    }

    @Test func theSizeEntryOpensTheNamedSizesAndChoosingOneResizesAndClosesBoth() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        try rig.open(1)
        #expect(try #require(view.widgetMenu?.rows[2]).accessibilityPerformPress())
        view.layoutSubtreeIfNeeded()
        let sizes = try #require(view.sizeMenu)
        #expect(sizes.rows.map(\.label.stringValue) == ["Small", "Medium", "Large"])
        #expect(sizes.rows.map(\.detail.stringValue) == ["1 × 1", "2 × 1", "2 × 2"])
        #expect(sizes.rows.map { $0.accessibilityValue() as? Bool } == [true, false, false])
        let menu = try #require(view.widgetMenu).panel.frame
        #expect(!sizes.panel.frame.intersects(menu))
        #expect(view.popupBounds.contains(sizes.panel.frame))
        #expect(sizes.rows[1].accessibilityPerformPress())
        #expect(edits == [.resize("weather", .wide)])
        #expect(view.widgetMenu == nil && view.sizeMenu == nil)
    }

    @Test func theKeyboardWalksTheSizesAndLeftClosesOnlyThatList() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        try rig.open(1)
        let editor = try #require(view.field.currentEditor() as? NSTextView)
        let command = { (selector: Selector) in
            view.control(view.field, textView: editor, doCommandBy: selector)
        }
        _ = command(#selector(NSResponder.moveDown))
        _ = command(#selector(NSResponder.moveDown))
        #expect(command(#selector(NSResponder.insertNewline)))
        #expect(view.sizeMenu != nil)
        #expect(command(#selector(NSResponder.moveLeft)))
        #expect(view.sizeMenu == nil && view.widgetMenu != nil)
        _ = command(#selector(NSResponder.insertNewline))
        #expect(command(#selector(NSResponder.moveDown)))
        #expect(command(#selector(NSResponder.insertNewline)))
        #expect(edits == [.resize("weather", .wide)])
        #expect(view.widgetMenu == nil && view.sizeMenu == nil)
    }

    @Test func aTileWithNothingToChooseBetweenHasNoSizeEntry() {
        view.widgets = (1...18).map { number in
            .init(
                id: "\(number)", name: "W\(number)", value: "", detail: "", action: "Open",
                spoken: "W")
        }
        view.layoutSubtreeIfNeeded()
        view.openWidgetMenu(0, at: .zero)
        #expect(!titles.contains("Size"))
    }

    @Test func controlClickingAWidgetOpensTheSameMenu() throws {
        tiles[0].mouseDown(with: try rig.event(.leftMouseDown, on: tiles[0], flags: [.control]))
        #expect(titles.first == "Open Clock")
    }

    @Test func theMenuHangsFromThePointerAndStaysOnScreen() throws {
        let bounds = view.popupBounds
        let spot = NSPoint(x: bounds.minX + 50, y: bounds.maxY - 50)
        view.openWidgetMenu(1, at: spot)
        let hanging = try #require(view.widgetMenu).panel.frame
        #expect(hanging.minX == spot.x && hanging.maxY == spot.y)
        view.closeWidgetMenu()
        view.openWidgetMenu(1, at: NSPoint(x: bounds.maxX + 500, y: bounds.minY - 500))
        let cornered = try #require(view.widgetMenu).panel.frame
        #expect(bounds.contains(cornered))
        #expect(cornered.maxX == bounds.maxX && cornered.minY == bounds.minY)
    }

    @Test func theEntriesRunTheirOwnActions() throws {
        var ran: [String] = []
        var edits: [WidgetSettings.Edit] = []
        view.onWidget = { ran.append($0.id) }
        view.onWidgetEdit = { edits.append($0) }
        try rig.open(1)
        #expect(try #require(view.widgetMenu?.rows[0]).accessibilityPerformPress())
        #expect(ran == ["weather"])
        #expect(view.widgetMenu == nil)
        #expect(tiles.allSatisfy { !$0.menuOpen })
        try rig.open(1)
        #expect(try #require(view.widgetMenu?.rows[5]).accessibilityPerformPress())
        #expect(edits == [.remove("weather")])
        try rig.open(1)
        #expect(try #require(view.widgetMenu?.rows[3]).accessibilityPerformPress())
        #expect(view.editingWidgets)
        #expect(view.selectedWidget == 1)
        #expect(view.widgetMenu == nil)
    }

    @Test func addWidgetsOpensEditModeWithNothingPicked() throws {
        try rig.open(1)
        #expect(try #require(view.widgetMenu?.rows[4]).accessibilityPerformPress())
        #expect(view.editingWidgets)
        #expect(view.selectedWidget == nil)
        #expect(view.widgetMenu == nil)
    }

    @Test func moveToOpensTheSpotPickerBesideTheMenuAndPlacesTheWidget() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        try rig.open(1)
        #expect(try #require(view.widgetMenu?.rows[1]).accessibilityPerformPress())
        view.layoutSubtreeIfNeeded()
        let picker = try #require(view.spotPicker)
        let menu = try #require(view.widgetMenu).panel.frame
        let beside = picker.panel.frame
        #expect(beside.maxX <= menu.minX || beside.minX >= menu.maxX)
        #expect(picker.panel.parent === rig.panel)
        #expect(view.widgetMenu != nil)
        view.place("weather", at: .leftTop)
        #expect(view.widgetMenu == nil)
        #expect(view.spotPicker == nil)
        #expect(edits == [.moving(["weather"], to: .leftTop, before: nil)])
    }

    @Test(arguments: [20.0, 200.0, 260.0, 330.0, 480.0, 700.0])
    func theSpotPickerStaysOnScreenWhereverTheMenuOpens(menuX: Double) throws {
        let window = try #require(unsafe view.window)
        let spot = window.convertPoint(toScreen: view.convert(NSPoint(x: menuX, y: 300), to: nil))
        view.openWidgetMenu(1, at: spot)
        view.openSpotPicker(for: view.widgetGrid.shown[1])
        let menu = try #require(view.widgetMenu).panel.frame
        let picker = try #require(view.spotPicker).panel.frame
        #expect(view.popupBounds.contains(picker))
        #expect(!picker.intersects(menu))
    }

    @Test func theKeyboardWalksTheMenuAndEscapeClosesIt() throws {
        var ran: [String] = []
        view.onWidget = { ran.append($0.id) }
        try rig.open(1)
        let editor = try #require(view.field.currentEditor() as? NSTextView)
        let command = { (selector: Selector) in
            view.control(view.field, textView: editor, doCommandBy: selector)
        }
        #expect(command(#selector(NSResponder.moveDown)))
        #expect(command(#selector(NSResponder.moveUp)))
        #expect(command(#selector(NSResponder.insertNewline)))
        #expect(ran == ["weather"])
        try rig.open(1)
        for _ in 1...3 {
            #expect(command(#selector(NSResponder.moveDown)))
        }
        #expect(command(#selector(NSResponder.insertNewline)))
        #expect(view.editingWidgets)
        view.finishEditingWidgets()
        try rig.open(1)
        #expect(command(#selector(NSResponder.cancelOperation)))
        #expect(view.widgetMenu == nil)
        #expect(view.selectedWidget == 1)
        try rig.open(1)
        _ = command(#selector(NSResponder.moveLeft))
        #expect(view.widgetMenu == nil)
    }

    @Test func clickingAnywhereInTheLauncherClosesTheMenu() throws {
        try rig.open(1)
        #expect(!view.handle(try rig.mouse(.leftMouseDown, at: NSPoint(x: 5, y: 5))))
        #expect(view.widgetMenu == nil)
        try rig.open(1)
        #expect(!view.handle(try rig.mouse(.rightMouseDown, at: NSPoint(x: 5, y: 5))))
        #expect(view.widgetMenu == nil)
        try rig.open(1)
        view.widgetGrid.onPress?(2)
        #expect(view.widgetMenu == nil)
        #expect(view.selectedWidget == 2)
    }

    @Test func clearingTheWidgetSelectionClosesItsMenuAndPicker() throws {
        try rig.open(1)
        #expect(try #require(view.widgetMenu?.rows[1]).accessibilityPerformPress())
        #expect(view.spotPicker != nil)
        view.selectWidget(nil)
        #expect(view.widgetMenu == nil)
        #expect(view.spotPicker == nil)
        try rig.open(1)
        view.selectWidget(2)
        #expect(view.widgetMenu == nil)
        #expect(tiles.allSatisfy { !$0.menuOpen })
    }

    @Test func returnWhileComposingDoesNotPlaceTheWidgetFromTheMenusPicker() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        let editor = try #require(view.field.currentEditor() as? NSTextView)
        editor.setMarkedText(
            "か", selectedRange: NSRange(location: 1, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0))
        try rig.open(1)
        #expect(try #require(view.widgetMenu?.rows[1]).accessibilityPerformPress())
        #expect(editor.hasMarkedText())
        let command = #selector(NSResponder.insertNewline)
        #expect(!view.control(view.field, textView: editor, doCommandBy: command))
        #expect(edits.isEmpty)
        #expect(view.spotPicker != nil)
    }

    @Test func theMenuIsOnlyForWidgetsOutsideEditMode() throws {
        view.editWidgets()
        tiles[1].rightMouseDown(with: try rig.event(.rightMouseDown, on: tiles[1]))
        #expect(view.widgetMenu == nil)
        #expect(tiles[1].accessibilityPerformShowMenu() == false)
    }

    @Test func aFloatingWidgetsMenuStaysOnScreen() throws {
        view.widgetSpots = ["clock": .leftTop, "weather": .rightBottom]
        view.layoutSubtreeIfNeeded()
        let tile = try #require(tiles.first { $0.widgetID == "weather" })
        #expect(tile.floating)
        tile.rightMouseDown(with: try rig.event(.rightMouseDown, on: tile))
        view.layoutSubtreeIfNeeded()
        let menu = try #require(view.widgetMenu).panel.frame
        #expect(view.popupBounds.contains(menu))
        #expect(titles.first == "Open Weather")
    }

    @Test func accessibilityCanShowTheMenu() {
        #expect(tiles[1].accessibilityPerformShowMenu())
        #expect(titles.first == "Open Weather")
    }
}
