import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetWorkbenchTests {
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

    @Test func aSelectedTileTurnsTheBarIntoItsMoveAndRemoveTools() {
        edit()
        #expect(view.selectedWidget == 0)
        #expect(!view.editBar.inspector.isHidden)
        #expect(view.editBar.name.stringValue == "Clock")
        #expect(view.editBar.move.label.stringValue == "In the panel")
        #expect(view.editBar.move.accessibilityLabel() == "Move to…")
        #expect(view.editBar.remove.accessibilityLabel() == "Remove Clock")
        #expect(view.editBar.notice.isHidden)
        view.selectWidget(nil)
        #expect(view.editBar.inspector.isHidden)
        #expect(!view.editBar.notice.isHidden)
        #expect(view.editBar.hint.stringValue == LauncherView.editHint)
        #expect(view.editBar.undo.isHidden)
    }

    @Test func moveToOpensTheSpotPickerAboveTheBarAndPlacesTheWidget() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        edit()
        view.editBar.move.onPress?()
        view.layoutSubtreeIfNeeded()
        let picker = try #require(view.spotPicker)
        #expect(view.editBar.move.fillColor == .controlAccentColor)
        let frame = picker.glass.convert(picker.glass.bounds, to: view)
        let move = view.editBar.move.convert(view.editBar.move.bounds, to: view)
        #expect(abs(frame.minX - move.minX) < 0.5)
        #expect(abs(frame.minY - (view.editBar.frame.maxY + 8)) < 0.5)
        press(kVK_Escape, "\u{1B}")
        #expect(view.spotPicker == nil)
        #expect(view.editingWidgets)
        #expect(view.editBar.move.fillColor == .clear)
        view.editBar.move.onPress?()
        press(kVK_RightArrow, "\u{F703}")
        press(kVK_Return, "\r")
        #expect(edits == [.place("clock", .rightMiddle, before: nil)])
        #expect(view.spotPicker == nil)
        #expect(view.editingWidgets)
    }

    @Test func clickingAGalleryPreviewAddsItToThePanelAndUndoTakesItBack() throws {
        var edits: [WidgetSettings.Edit] = []
        var undos = 0
        view.onWidgetEdit = { edit in
            edits.append(edit)
            view.widgets = widgets + [Self.widget("system")]
        }
        view.onUndoWidgetEdit = {
            undos += 1
            view.widgets = widgets
        }
        edit()
        let card = try #require(view.gallery.cards.first { $0.card.id == "system" })
        #expect(card.accessibilityPerformPress())
        #expect(edits == [.add("system")])
        #expect(view.selectedWidget == 3)
        #expect(view.editBar.hint.stringValue == "System added · In the panel")
        #expect(!view.editBar.notice.isHidden)
        #expect(!view.editBar.undo.isHidden)
        #expect(view.gallery.placed["system"] == .panel)
        press(kVK_ANSI_Z, "z", [.command])
        #expect(undos == 1)
        #expect(view.editBar.hint.stringValue == "Undone")
        #expect(view.editBar.undo.isHidden)
        #expect(view.gallery.placed["system"] == nil)
        #expect(!view.performKeyEquivalent(with: try key(kVK_ANSI_Z, "z", [.command])))
        #expect(undos == 1)
    }

    @Test func clickingAnAddedPreviewSelectsItsTileAndSaysWhereItIs() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        edit()
        let card = try #require(view.gallery.cards.first { $0.card.id == "battery" })
        #expect(card.accessibilityPerformPress())
        #expect(edits.isEmpty)
        #expect(view.selectedWidget == 2)
        #expect(view.editBar.hint.stringValue == "Battery is In the panel")
        #expect(view.editBar.undo.isHidden)
    }

    @Test func typingFiltersTheGalleryAndArrowsStillMoveBetweenTiles() {
        edit()
        type("bat")
        #expect(view.gallery.query == "bat")
        #expect(view.gallery.shown.map(\.card.id) == ["battery"])
        #expect(view.editingWidgets)
        #expect(view.results.isHidden)
        press(kVK_RightArrow, "\u{F703}")
        #expect(view.selectedWidget == 0)
        press(kVK_DownArrow, "\u{F701}")
        press(kVK_UpArrow, "\u{F700}")
        #expect(view.selectedWidget == 0)
    }

    @Test func optionArrowsSendTheSelectedWidgetToTheNextSpot() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        edit()
        #expect(view.handle(try key(kVK_LeftArrow, "\u{F702}", [.option])))
        #expect(edits == [.place("clock", .leftMiddle, before: nil)])
        #expect(view.editBar.hint.stringValue == "Clock moved · Left · Middle")
        #expect(!view.handle(try key(kVK_ANSI_A, "a", [.option])))
        view.selectWidget(nil)
        #expect(!view.handle(try key(kVK_LeftArrow, "\u{F702}", [.option])))
        #expect(edits.count == 1)
    }

    @Test func aKeptQueryStepsAsideForEditModeAndComesBackAfterwards() {
        var queries: [String] = []
        view.onQuery = { queries.append($0) }
        view.field.stringValue = "safari"
        view.show(view.results.sections)
        view.editWidgets()
        #expect(queries == [""])
        #expect(view.field.stringValue.isEmpty)
        #expect(!view.editingWidgets)
        view.show(view.results.sections)
        #expect(view.editingWidgets)
        view.finishEditingWidgets()
        #expect(view.field.stringValue == "safari")
        #expect(queries == ["", "safari"])
        view.show(view.results.sections)
        view.editWidgets()
        #expect(view.field.stringValue.isEmpty)
        view.endBrowsing()
        #expect(!view.editingWidgets)
        #expect(view.field.stringValue == "safari")
        view.show(view.results.sections)
        view.editWidgets()
        #expect(!view.editingWidgets)
        type("x")
        #expect(view.field.stringValue == "x")
        view.show(view.results.sections)
        #expect(!view.editingWidgets)
    }

    @Test func resultsArrivingDuringEditModeStayOutOfTheWayAndLeavingSearchesAgain() {
        var queries: [String] = []
        view.onQuery = { queries.append($0) }
        edit()
        type("bat")
        #expect(queries.isEmpty)
        let rows = view.results.rows.count
        view.show([.init(title: "Files", items: [item("Battery Report"), item("Bath")])])
        #expect(view.editingWidgets)
        #expect(view.results.isHidden)
        #expect(!view.widgetGrid.isHidden)
        #expect(view.results.rows.count == rows)
        view.finishEditingWidgets()
        #expect(queries == [""])
        #expect(view.field.stringValue.isEmpty)
    }

    @Test func resultsArrivingWhileEditingStayHiddenBehindTheGallery() {
        edit()
        view.showLyrics(false)
        #expect(view.results.isHidden)
        view.showGrid([], home: nil, keeping: nil)
        #expect(view.results.isHidden)
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
