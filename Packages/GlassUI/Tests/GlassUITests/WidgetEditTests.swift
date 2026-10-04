import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetEditTests {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 548),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let view = LauncherView()
    private let widgets = ["clock", "weather", "battery"].map { id in
        WidgetGrid.Widget(
            id: id, name: id.capitalized, value: id, detail: "", action: "Open \(id.capitalized)",
            spoken: id.capitalized)
    }

    init() {
        panel.contentView = view
        view.results.sections = [.init(title: "Commands", items: [item("Safari"), item("Notes")])]
        view.widgets = widgets
        view.pills = [
            .init(
                id: "uptime", name: "Uptime", symbol: "clock", value: "17h",
                action: "Show System Report")
        ]
        panel.makeFirstResponder(view.field)
    }

    @Test func commandKOnAWidgetOffersItsActionAndEditWidgets() throws {
        var ran: [String] = []
        view.onWidget = { ran.append($0.id) }
        press(kVK_UpArrow, "\u{F700}")
        press(kVK_RightArrow, "\u{F703}")
        press(kVK_ANSI_K, "k", [.command])
        let menu = try #require(view.actionPanel)
        #expect(view.choosingAction)
        #expect(view.selectedWidget == 1)
        #expect(menu.header.stringValue == "Weather")
        #expect(menu.rows.map(\.label.stringValue) == ["Open Weather", "Edit Widgets"])
        #expect(try #require(menu.rows.first).accessibilityPerformPress())
        #expect(ran == ["weather"])
        press(kVK_ANSI_K, "k", [.command])
        #expect(try #require(view.actionPanel?.rows.last).accessibilityPerformPress())
        #expect(!view.choosingAction)
        #expect(view.editingWidgets)
        #expect(view.selectedWidget == 1)
        #expect(ran == ["weather"])
    }

    @Test func editModeSwapsTheSearchBarDimsTheListAndMarksTheTiles() {
        edit()
        view.layoutSubtreeIfNeeded()
        #expect(view.field.isHidden)
        #expect(!view.editBar.isHidden)
        #expect(view.editBar.title.stringValue == "Editing widgets")
        #expect(view.editBar.add.accessibilityLabel() == "Add Widget")
        #expect(view.editBar.done.title == "Done")
        #expect(view.results.alphaValue == 0.45)
        #expect(view.results.hidesSelection)
        #expect(view.widgetGrid.tiles.map(\.editing) == [true, true, true])
        #expect(view.widgetGrid.tiles.allSatisfy { !$0.remove.isHidden && !$0.grip.isHidden })
        #expect(view.statusBar.isHidden)
        #expect(view.contextPill.text == "Drag to reorder · ⌫ removes the selected widget")
        #expect(view.contextPill.symbol == "square.grid.2x2")
        #expect(view.actionLabel.stringValue == "Done")
        #expect(
            (view.actionCapsule.contentView as? NSStackView)?.arrangedSubviews
                == [view.actionLabel, view.actionKeycap])
        #expect(panel.firstResponder === view.editBar)
        #expect(view.widgetsBottom == 393)
        let iconWidth = view.icon.frame.width
        #expect(iconWidth < 30)
        #expect(abs(view.editBar.title.convert(.zero, to: view).x - view.field.frame.minX) < 3)
        #expect(abs(view.editBar.done.convert(view.editBar.done.bounds, to: view).maxX - 746) < 1)
        let tile = view.widgetGrid.tiles[0]
        let badge = tile.convert(tile.remove.frame, to: view.widgetGrid)
        let frame = tile.convert(tile.bounds, to: view.widgetGrid)
        #expect(abs(badge.minX - (frame.minX - 8)) < 1)
        #expect(abs(badge.minY - (frame.minY - 8)) < 1)
        #expect(abs(badge.width - 22) < 0.5 && abs(badge.height - 22) < 0.5)
    }

    @Test func tilesTiltBothWaysUnlessReduceMotionIsOn() {
        view.widgetGrid.reducesMotion = { false }
        edit()
        view.layoutSubtreeIfNeeded()
        #expect(view.widgetGrid.tiles.map(\.frameCenterRotation) == [-0.6, 0.6, -0.6])
        let centre = view.widgetGrid.tiles[0].convert(
            NSPoint(x: view.widgetGrid.tiles[0].bounds.midX, y: 39), to: view.widgetGrid)
        #expect(abs(centre.x - (14 + (732 - 40) / 12)) < 0.5)
        #expect(abs(centre.y - (12 + 39)) < 0.5)
        view.finishEditingWidgets()
        view.layoutSubtreeIfNeeded()
        #expect(view.widgetGrid.tiles.allSatisfy { $0.frameCenterRotation == 0 })
        view.widgetGrid.reducesMotion = { true }
        edit()
        view.layoutSubtreeIfNeeded()
        #expect(view.widgetGrid.tiles.allSatisfy { $0.frameCenterRotation == 0 })
        #expect(view.widgetGrid.tiles.map(\.editing) == [true, true, true])
    }

    @Test func deleteRemovesTheSelectedWidgetAndArrowsMoveTheSelection() {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.pressWidget(1)
        edit()
        press(kVK_Delete, "\u{7F}")
        #expect(edits == [.remove("weather")])
        press(kVK_RightArrow, "\u{F703}")
        press(kVK_RightArrow, "\u{F703}")
        #expect(view.selectedWidget == 2)
        press(kVK_ForwardDelete, "\u{F728}")
        #expect(edits == [.remove("weather"), .remove("battery")])
        press(kVK_LeftArrow, "\u{F702}")
        press(kVK_LeftArrow, "\u{F702}")
        press(kVK_LeftArrow, "\u{F702}")
        #expect(view.selectedWidget == 0)
        press(kVK_ANSI_A, "a")
        #expect(view.field.stringValue.isEmpty)
        #expect(view.editingWidgets)
        view.widgets = [widgets[1], widgets[2]]
        #expect(view.selectedWidget == nil)
        press(kVK_Delete, "\u{7F}")
        #expect(edits.count == 2)
        press(kVK_RightArrow, "\u{F703}")
        #expect(view.selectedWidget == 0)
    }

    @Test func theRemoveButtonRemovesItsTileAndClicksOnlySelect() throws {
        var edits: [WidgetSettings.Edit] = []
        var ran: [String] = []
        view.onWidgetEdit = { edits.append($0) }
        view.onWidget = { ran.append($0.id) }
        edit()
        view.layoutSubtreeIfNeeded()
        let tile = view.widgetGrid.tiles[2]
        let badge = tile.convert(
            NSPoint(x: tile.remove.frame.minX + 2, y: tile.remove.frame.maxY - 2), to: nil)
        #expect(view.widgetGrid.hitTest(view.convert(badge, from: nil)) === tile)
        tile.mouseDown(with: try mouse(at: badge))
        #expect(edits == [.remove("battery")])
        #expect(tile.accessibilityCustomActions()?.map(\.name) == ["Remove"])
        #expect(tile.accessibilityCustomActions()?.first?.handler?() == true)
        #expect(edits == [.remove("battery"), .remove("battery")])
        #expect(view.widgetGrid.tiles[0].accessibilityPerformPress())
        #expect(view.selectedWidget == 0)
        #expect(ran.isEmpty)
        let click = try mouse(at: view.results.convert(NSPoint(x: 40, y: 40), to: nil))
        #expect(view.handle(click))
    }

    @Test func modifiedKeysLeaveTheDimmedResultsAlone() {
        var runs: [Int] = []
        view.actions = { _ in
            [
                .init("Run Command"),
                .init("Show in Finder", keys: LauncherView.Action.secondaryKeys),
                .init("Copy Name", keys: ["⌘", "C"]),
            ]
        }
        view.onRun = { runs.append($1) }
        edit()
        press(kVK_Return, "\r", [.command])
        press(kVK_ANSI_C, "c", [.command])
        #expect(runs.isEmpty)
        view.finishEditingWidgets()
        press(kVK_ANSI_C, "c", [.command])
        #expect(runs == [2])
    }

    @Test func returnEscapeAndDoneLeaveEditModeAndTheLauncherClosingEndsItToo() {
        var ends = 0
        var adds = 0
        view.onEndEditingWidgets = { ends += 1 }
        view.onAddWidgets = { adds += 1 }
        for leave in [
            { press(kVK_Return, "\r") }, { press(kVK_Escape, "\u{1B}") },
            { view.editBar.done.performClick(nil) }, { view.endBrowsing() },
        ] {
            edit()
            leave()
            #expect(!view.editingWidgets)
            #expect(!view.field.isHidden && view.editBar.isHidden)
            #expect(view.results.alphaValue == 1)
            #expect(!view.statusBar.isHidden)
            #expect(view.widgetGrid.tiles.allSatisfy { !$0.editing && $0.remove.isHidden })
            #expect(!view.actionsToggle.isHidden)
            #expect(panel.firstResponder === view.field.currentEditor())
        }
        #expect(ends == 4)
        view.finishEditingWidgets()
        #expect(ends == 4)
        edit()
        view.editBar.add.performClick(nil)
        #expect(adds == 1)
        #expect(view.editingWidgets)
    }

    @Test func editingShowsEveryWidgetInlineWhateverThePlacement() {
        view.widgets = (1...7).map { number in
            WidgetGrid.Widget(
                id: "\(number)", name: "Widget \(number)", value: "\(number)", detail: "",
                action: "Open \(number)", spoken: "\(number)")
        }
        view.widgetLayout = .strip
        for arrangement: WidgetSettings.Arrangement in [.inPanel, .above] {
            arrange(arrangement)
            edit()
            #expect(view.widgetGrid.shown.count == 7)
            #expect(view.widgetGrid.floats.isEmpty)
            #expect(view.widgetGrid.tiles.allSatisfy { unsafe $0.superview === view.widgetGrid })
            view.finishEditingWidgets()
        }
        #expect(view.widgetGrid.floats.count == 7)
        arrange(.inPanel)
        #expect(view.widgetGrid.shown.count == 6)
    }

    @Test func removingEveryWidgetKeepsTheGridForDrops() {
        edit()
        view.widgets = []
        #expect(view.editingWidgets)
        #expect(!view.widgetGrid.isHidden)
        view.finishEditingWidgets()
        #expect(view.widgetGrid.isHidden)
    }

    private func edit() {
        if view.selectedWidget == nil {
            view.selectWidget(0)
        }
        view.editWidgets()
    }

    private func mouse(at point: NSPoint) throws -> NSEvent {
        try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown, location: point, modifierFlags: [], timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1,
                pressure: 1))
    }

    private func press(
        _ keyCode: Int, _ characters: String, _ modifiers: NSEvent.ModifierFlags = []
    ) {
        guard
            let event = NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, characters: characters,
                charactersIgnoringModifiers: characters, isARepeat: false,
                keyCode: UInt16(keyCode))
        else {
            Issue.record("Could not make a key event for \(keyCode)")
            return
        }
        if modifiers.contains(.command), panel.performKeyEquivalent(with: event) { return }
        panel.sendEvent(event)
    }

    private func item(_ title: String) -> ResultList.Item {
        .init(
            id: title, title: title, subtitle: "", kind: "Command", symbol: "star",
            action: "Run Command")
    }

    private func arrange(_ arrangement: WidgetSettings.Arrangement) {
        view.widgetSpots = WidgetSettings().spots(arrangement, from: view.widgets.map(\.id))
    }
}
