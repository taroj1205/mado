import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetSpotKeysTests {
    private let panel = NSPanel(
        contentRect: NSRect(x: 400, y: 200, width: 760, height: 548),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let view = LauncherView()

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
        view.widgets = (1...7).map(numbered)
        panel.makeFirstResponder(view.field)
        view.layoutSubtreeIfNeeded()
    }

    @Test func moveOpensThePickerBesideTheActionsAndReturnMovesTheWidget() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        let menu = try openPicker(on: 1)
        let picker = try #require(view.spotPicker)
        #expect(picker.title.stringValue == "Move Widget 2")
        #expect(picker.value == .panel)
        #expect(picker.marks.filter(\.isOn).map(\.spot) == [.panel])
        #expect(abs(picker.glass.frame.maxX + WidgetSpotPicker.gap - menu.glass.frame.minX) < 1)
        press(kVK_RightArrow, "\u{F703}")
        #expect(picker.value == .rightMiddle)
        #expect(picker.label.stringValue == "Right · Middle")
        #expect(edits.isEmpty)
        press(kVK_Return, "\r")
        #expect(edits == [.place("2", .rightMiddle, before: nil)])
        #expect(!view.choosingAction)
        #expect(view.spotPicker == nil)
    }

    @Test func escapeClosesThePickerBeforeTheActions() throws {
        _ = try openPicker(on: 0)
        press(kVK_Escape, "\u{1B}")
        #expect(view.spotPicker == nil)
        #expect(view.choosingAction)
        press(kVK_Escape, "\u{1B}")
        #expect(!view.choosingAction)
    }

    @Test func clickingASpotMovesTheWidgetThereAtOnce() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        _ = try openPicker(on: 0)
        let mark = try #require(view.spotPicker?.marks.first { $0.spot == .aboveCentre })
        #expect(mark.accessibilityPerformPress())
        #expect(edits == [.place("1", .aboveCentre, before: nil)])
        #expect(!view.choosingAction)
    }

    @Test func aSpotWithNoRoomIsRefusedAndThePickerStays() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.widgetSpots = Dictionary(uniqueKeysWithValues: (2...7).map { ("\($0)", .leftTop) })
        _ = try openPicker(on: 0)
        press(kVK_LeftArrow, "\u{F702}")
        press(kVK_UpArrow, "\u{F700}")
        #expect(view.spotPicker?.value == .leftTop)
        press(kVK_Return, "\r")
        #expect(edits.isEmpty)
        #expect(view.spotPicker != nil)
    }

    @Test func optionArrowsSendTheSelectedWidgetToTheNextSpotInEditMode() {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.selectWidget(0)
        view.editWidgets()
        press(kVK_DownArrow, "\u{F701}", [.option])
        press(kVK_RightArrow, "\u{F703}", [.option])
        #expect(
            edits == [
                .place("1", .belowCentre, before: nil), .place("1", .rightMiddle, before: nil),
            ])
        press(kVK_RightArrow, "\u{F703}")
        #expect(view.selectedWidget == 1)
    }

    @Test func returnWhileComposingCommitsTheTextInsteadOfMoving() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        _ = try openPicker(on: 0)
        let editor = try #require(panel.firstResponder as? NSTextView)
        editor.setMarkedText(
            "か", selectedRange: NSRange(location: 1, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(editor.hasMarkedText())
        press(kVK_Return, "\r")
        #expect(edits.isEmpty)
        #expect(view.spotPicker != nil)
    }

    @Test func filteringTheActionsKeepsThePickerInsideTheLauncher() throws {
        let menu = try openPicker(on: 0)
        let picker = try #require(view.spotPicker)
        #expect(abs(picker.glass.frame.maxY - menu.glass.frame.maxY) < 1)
        press(kVK_ANSI_R, "r")
        press(kVK_ANSI_E, "e")
        press(kVK_ANSI_M, "m")
        view.layoutSubtreeIfNeeded()
        #expect(menu.rows.count == 1)
        #expect(picker.glass.frame.minY >= view.bounds.minY)
        #expect(view.bounds.contains(picker.glass.frame))
    }

    private func openPicker(on index: Int) throws -> ActionPanel {
        view.selectWidget(index)
        press(kVK_ANSI_K, "k", [.command])
        let menu = try #require(view.actionPanel)
        #expect(menu.rows[1].label.stringValue == "Move…")
        #expect(menu.rows[1].accessibilityPerformPress())
        #expect(view.choosingAction)
        view.layoutSubtreeIfNeeded()
        return menu
    }

    private func numbered(_ number: Int) -> WidgetGrid.Widget {
        .init(
            id: "\(number)", name: "Widget \(number)", value: "\(number)", detail: "",
            action: "Open \(number)", spoken: "Widget \(number)")
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
        if view.handle(event) { return }
        if modifiers.contains(.command), panel.performKeyEquivalent(with: event) { return }
        panel.sendEvent(event)
    }
}
