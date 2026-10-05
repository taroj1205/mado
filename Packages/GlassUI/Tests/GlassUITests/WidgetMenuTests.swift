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
                "Open Weather", "Move to…", "Edit Widgets", "Add Widgets…", "Remove Weather",
            ])
        #expect(menu.rows[0].keycaps.map(\.name.stringValue) == ["↵"])
        #expect(menu.rows[1].detail.stringValue == "In the panel")
        #expect(unsafe menu.rows[1].chevron.superview != nil)
        #expect(menu.rows[4].isDestructive)
        #expect(view.selectedWidget == 1)
        #expect(tiles.map(\.menuOpen) == [false, true, false])
        #expect(view.bounds.contains(menu.glass.frame))
        #expect(menu.glass.frame.width == WidgetMenu.width)
    }

    @Test func controlClickingAWidgetOpensTheSameMenu() throws {
        tiles[0].mouseDown(with: try rig.event(.leftMouseDown, on: tiles[0], flags: [.control]))
        #expect(titles.first == "Open Clock")
    }

    @Test func theMenuIsPlacedAtThePointerAndKeptInsideTheLauncher() throws {
        tiles[2].rightMouseDown(with: try rig.event(.rightMouseDown, on: tiles[2]))
        view.layoutSubtreeIfNeeded()
        let low = try #require(view.widgetMenu).glass.frame
        #expect(low.minX > 0 && low.maxX <= view.bounds.maxX - 10)
        view.closeWidgetMenu()
        let corner = try rig.event(.rightMouseDown, on: tiles[2], at: NSPoint(x: 2, y: 2))
        tiles[2].rightMouseDown(with: corner)
        view.layoutSubtreeIfNeeded()
        let high = try #require(view.widgetMenu).glass.frame
        #expect(high.minY >= 10)
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
        #expect(try #require(view.widgetMenu?.rows[4]).accessibilityPerformPress())
        #expect(edits == [.remove("weather")])
        try rig.open(1)
        #expect(try #require(view.widgetMenu?.rows[2]).accessibilityPerformPress())
        #expect(view.editingWidgets)
        #expect(view.selectedWidget == 1)
        #expect(view.widgetMenu == nil)
    }

    @Test func addWidgetsOpensEditModeWithNothingPicked() throws {
        try rig.open(1)
        #expect(try #require(view.widgetMenu?.rows[3]).accessibilityPerformPress())
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
        let menu = try #require(view.widgetMenu).glass.frame
        let beside = picker.glass.frame
        #expect(beside.maxX <= menu.minX || beside.minX >= menu.maxX)
        #expect(view.widgetMenu != nil)
        view.place("weather", at: .leftTop)
        #expect(view.widgetMenu == nil)
        #expect(view.spotPicker == nil)
        #expect(edits == [.moving(["weather"], to: .leftTop, before: nil)])
    }

    @Test(arguments: [20.0, 200.0, 260.0, 330.0, 480.0, 700.0])
    func theSpotPickerStaysInsideTheLauncherWhereverTheMenuOpens(menuX: Double) throws {
        let window = try #require(unsafe view.window)
        let spot = window.convertPoint(toScreen: view.convert(NSPoint(x: menuX, y: 300), to: nil))
        view.openWidgetMenu(1, at: spot)
        view.openSpotPicker(for: view.widgetGrid.shown[1])
        view.layoutSubtreeIfNeeded()
        let menu = try #require(view.widgetMenu).glass.frame
        let picker = try #require(view.spotPicker).glass.frame
        #expect(view.bounds.contains(picker))
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
        #expect(command(#selector(NSResponder.moveDown)))
        #expect(command(#selector(NSResponder.moveDown)))
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

    @Test func clickingAnywhereElseClosesTheMenuButNotClickingInIt() throws {
        try rig.open(1)
        let inside = try #require(view.widgetMenu).glass
        let point = inside.convert(NSPoint(x: inside.bounds.midX, y: inside.bounds.midY), to: nil)
        #expect(!view.handle(try rig.mouse(.leftMouseDown, at: point)))
        #expect(view.widgetMenu != nil)
        #expect(!view.handle(try rig.mouse(.rightMouseDown, at: point)))
        #expect(view.widgetMenu != nil)
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

    @Test func theMenuIsOnlyForWidgetsOutsideEditMode() throws {
        view.editWidgets()
        tiles[1].rightMouseDown(with: try rig.event(.rightMouseDown, on: tiles[1]))
        #expect(view.widgetMenu == nil)
        #expect(tiles[1].accessibilityPerformShowMenu() == false)
    }

    @Test func aFloatingWidgetsMenuStaysInsideTheLauncher() throws {
        view.widgetSpots = ["clock": .leftTop, "weather": .rightBottom]
        view.layoutSubtreeIfNeeded()
        let tile = try #require(tiles.first { $0.widgetID == "weather" })
        #expect(tile.floating)
        tile.rightMouseDown(with: try rig.event(.rightMouseDown, on: tile))
        view.layoutSubtreeIfNeeded()
        let menu = try #require(view.widgetMenu).glass.frame
        #expect(view.bounds.contains(menu))
        #expect(titles.first == "Open Weather")
    }

    @Test func accessibilityCanShowTheMenu() {
        #expect(tiles[1].accessibilityPerformShowMenu())
        #expect(titles.first == "Open Weather")
    }
}
