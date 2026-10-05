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
    private let widgets = ["clock", "weather", "battery"].map(Self.widget)

    init() {
        panel.contentView = view
        view.results.sections = [.init(title: "Commands", items: [item("Safari"), item("Notes")])]
        view.widgets = widgets
        view.widgetCatalogue = ["clock", "weather", "battery", "system"].map { id in
            .init(id: id, name: id.capitalized, summary: "About \(id)", group: .today)
        }
        view.pills = [
            .init(
                id: "uptime", name: "Uptime", symbol: "clock", value: "17h",
                action: "Show System Report")
        ]
        panel.makeFirstResponder(view.field)
    }

    nonisolated private static func widget(_ id: String) -> WidgetGrid.Widget {
        .init(
            id: id, name: id.capitalized, value: id, detail: "", action: "Open \(id.capitalized)",
            spoken: id.capitalized)
    }

    @Test func commandKOnAWidgetOffersItsActionMoveEditAndRemove() throws {
        var ran: [String] = []
        view.onWidget = { ran.append($0.id) }
        press(kVK_UpArrow, "\u{F700}")
        press(kVK_RightArrow, "\u{F703}")
        press(kVK_ANSI_K, "k", [.command])
        let menu = try #require(view.actionPanel)
        #expect(view.choosingAction)
        #expect(view.selectedWidget == 1)
        #expect(menu.header.stringValue == "Weather")
        #expect(
            menu.rows.map(\.label.stringValue)
                == ["Open Weather", "Move…", "Edit Widgets", "Remove Widget"])
        #expect(menu.rows[1].detail.stringValue == "In the panel")
        #expect(try #require(menu.rows.first).accessibilityPerformPress())
        #expect(ran == ["weather"])
        press(kVK_ANSI_K, "k", [.command])
        #expect(try #require(view.actionPanel?.rows[2]).accessibilityPerformPress())
        #expect(!view.choosingAction)
        #expect(view.editingWidgets)
        #expect(view.selectedWidget == 1)
        #expect(ran == ["weather"])
    }

    @Test func editModeSearchesWidgetsAndShowsTheGalleryInPlaceOfTheList() {
        var editing: [Bool] = []
        view.onWidgetEditing = { editing.append($0) }
        edit()
        view.layoutSubtreeIfNeeded()
        #expect(editing == [true])
        #expect(!view.field.isHidden)
        #expect(view.field.placeholderString == "Search widgets…")
        #expect(panel.firstResponder === view.field.currentEditor())
        #expect(!view.doneButton.isHidden)
        #expect(view.doneButton.label.stringValue == "Done")
        #expect(view.results.isHidden)
        #expect(!view.gallery.isHidden)
        #expect(view.actionCapsule.isHidden)
        #expect(view.contextPill.isHidden)
        #expect(view.statusBar.isHidden)
        #expect(!view.editBar.isHidden)
        #expect(view.widgetGrid.tiles.map(\.editing) == [true, true, true])
        #expect(view.gallery.placed == ["clock": .panel, "weather": .panel, "battery": .panel])
        let done = view.doneButton.convert(view.doneButton.bounds, to: view)
        #expect(abs(done.maxX - 746) < 1)
        #expect(done.height == 28)
        #expect(view.field.frame.maxX < done.minX - 8)
        let gallery = view.gallery.frame
        #expect(abs(gallery.maxY - view.widgetGrid.frame.minY) < 0.5)
        #expect(gallery.minY == 0)
        let bar = view.editBar.frame
        #expect(bar.minX == 10 && bar.minY == 10)
    }

    @Test func deleteRemovesTheSelectedWidgetAndArrowsMoveTheSelection() {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.selectWidget(1)
        edit()
        press(kVK_Delete, "\u{7F}")
        #expect(edits == [.remove("weather")])
        #expect(view.editBar.hint.stringValue == "Weather removed")
        view.layoutSubtreeIfNeeded()
        #expect(view.editBar.hint.frame.width >= view.editBar.hint.intrinsicContentSize.width)
        press(kVK_RightArrow, "\u{F703}")
        press(kVK_RightArrow, "\u{F703}")
        #expect(view.selectedWidget == 2)
        press(kVK_ForwardDelete, "\u{F728}")
        #expect(edits == [.remove("weather"), .remove("battery")])
        press(kVK_LeftArrow, "\u{F702}")
        press(kVK_LeftArrow, "\u{F702}")
        press(kVK_LeftArrow, "\u{F702}")
        #expect(view.selectedWidget == 0)
        view.editBar.remove.performClick(nil)
        #expect(edits.last == .remove("clock"))
        view.widgets = [widgets[1], widgets[2]]
        #expect(view.selectedWidget == nil)
        press(kVK_Delete, "\u{7F}")
        #expect(edits.count == 3)
        press(kVK_RightArrow, "\u{F703}")
        #expect(view.selectedWidget == 0)
    }

    @Test func tilesTiltBothWaysUnlessReduceMotionIsOn() {
        view.widgetGrid.reducesMotion = { false }
        edit()
        view.layoutSubtreeIfNeeded()
        #expect(view.widgetGrid.tiles.map(\.frameCenterRotation) == [-0.6, 0.6, -0.6])
        view.finishEditingWidgets()
        view.layoutSubtreeIfNeeded()
        #expect(view.widgetGrid.tiles.allSatisfy { $0.frameCenterRotation == 0 })
        view.widgetGrid.reducesMotion = { true }
        edit()
        view.layoutSubtreeIfNeeded()
        #expect(view.widgetGrid.tiles.allSatisfy { $0.frameCenterRotation == 0 })
        #expect(view.widgetGrid.tiles.map(\.editing) == [true, true, true])
    }

    @Test func aStripKeepsItsLayoutInEditMode() {
        view.widgetLayout = .strip
        view.layoutSubtreeIfNeeded()
        let height = view.widgetGrid.frame.height
        edit()
        view.layoutSubtreeIfNeeded()
        #expect(view.widgetGrid.frame.height == height)
        let compact = view.widgetGrid.tiles.map(\.compact)
        #expect(!compact.isEmpty && !compact.contains(false))
        #expect(!view.widgetGrid.fillsPanel)
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
        #expect(tile.accessibilityCustomActions()?.first?.name == "Remove")
        #expect(tile.accessibilityCustomActions()?.first?.handler?() == true)
        #expect(edits == [.remove("battery"), .remove("battery")])
        #expect(view.widgetGrid.tiles[0].accessibilityPerformPress())
        #expect(view.selectedWidget == 0)
        #expect(ran.isEmpty)
    }

    @Test func modifiedKeysLeaveTheHiddenResultsAlone() {
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

    @Test func returnEscapeDoneAndTheLauncherClosingLeaveEditMode() {
        var editing: [Bool] = []
        view.onWidgetEditing = { editing.append($0) }
        for leave in [
            { press(kVK_Return, "\r") }, { press(kVK_Escape, "\u{1B}") },
            { view.doneButton.onPress?() }, { view.endBrowsing() },
        ] {
            edit()
            type("clo")
            leave()
            #expect(!view.editingWidgets)
            #expect(view.field.stringValue.isEmpty)
            #expect(view.field.placeholderString == "Search apps and commands…")
            #expect(view.doneButton.isHidden && view.gallery.isHidden && view.editBar.isHidden)
            #expect(!view.results.isHidden)
            #expect(!view.statusBar.isHidden)
            #expect(view.widgetGrid.tiles.allSatisfy { !$0.editing && $0.remove.isHidden })
            #expect(!view.actionsToggle.isHidden)
            #expect(panel.firstResponder === view.field.currentEditor())
        }
        #expect(editing == [true, false, true, false, true, false, true, false])
        view.finishEditingWidgets()
        #expect(editing.count == 8)
    }

    @Test func editModeWaitsForTheEmptyQueryAndOpensWithoutAnyWidget() {
        view.widgets = []
        view.field.stringValue = "safari"
        view.show(view.results.sections)
        view.field.stringValue = ""
        view.editWidgets()
        #expect(!view.editingWidgets)
        view.show(view.results.sections)
        #expect(view.editingWidgets)
        #expect(!view.widgetGrid.isHidden)
        #expect(!view.widgetGrid.dock.isHidden)
        #expect(!view.widgetGrid.dockCaption.isHidden)
        view.widgets = widgets
        #expect(view.widgetGrid.dockCaption.isHidden)
        view.widgets = []
        view.finishEditingWidgets()
        #expect(view.widgetGrid.isHidden)
    }

    private func edit() {
        if view.selectedWidget == nil {
            view.selectWidget(0)
        }
        view.editWidgets()
    }

    private func type(_ text: String) {
        view.field.currentEditor()?.insertText(text)
    }

    private func mouse(at point: NSPoint) throws -> NSEvent {
        try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown, location: point, modifierFlags: [], timestamp: 0,
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

    private func press(
        _ keyCode: Int, _ characters: String, _ modifiers: NSEvent.ModifierFlags = []
    ) {
        guard let event = try? key(keyCode, characters, modifiers), !view.handle(event) else {
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
}
