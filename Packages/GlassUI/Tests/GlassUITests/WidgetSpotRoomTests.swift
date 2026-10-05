import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetSpotRoomTests {
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
        panel.makeFirstResponder(view.field)
    }

    @Test func aWidgetTheStripHidesStillTakesItsRoom() {
        view.widgets = (1...5).map { widget("\($0)") } + [widget("wide", wide: true), widget("f")]
        view.widgetLayout = .strip
        view.widgetSpots = ["f": .leftTop]
        #expect(view.widgetGrid.shown.map(\.id) == ["1", "2", "3", "4", "5", "f"])
        #expect(!view.widgetGrid.accepts("f", at: .panel, before: nil))
    }

    @Test func anUnavailableWidgetKeepsItsRoomForWhenItComesBack() {
        let away = WidgetGrid.Widget(
            id: "away", name: "away", content: .unavailable(title: "away", summary: ""),
            action: "Open away", spoken: "away", isWide: true)
        view.widgets = (1...5).map { widget("\($0)") } + [away, widget("f")]
        view.widgetLayout = .strip
        view.widgetSpots = ["f": .leftTop]
        #expect(view.widgetGrid.shown.map(\.id) == ["1", "2", "3", "4", "5", "f"])
        #expect(!view.widgetGrid.accepts("f", at: .panel, before: nil))
        #expect(!view.widgetGrid.accepts("away", at: .leftTop, before: nil))
    }

    @Test func roomIsCheckedWhereTheWidgetWouldGo() {
        view.widgets = (1...10).map { widget("\($0)") } + [widget("wide", wide: true)]
        view.widgetSpots = ["wide": .leftTop]
        #expect(view.widgetGrid.accepts("wide", at: .panel, before: nil))
        #expect(!view.widgetGrid.accepts("wide", at: .panel, before: "6"))
    }

    @Test func thePickerKeepsMovingItsWidgetWhenTheSelectionGoes() throws {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.widgets = (1...3).map { widget("\($0)") }
        try openPicker()
        view.selectWidget(nil)
        press(kVK_RightArrow, "\u{F703}")
        press(kVK_Return, "\r")
        #expect(edits == [.place("1", .rightMiddle, before: nil)])
    }

    @Test func closingThePickerLetsItGo() throws {
        view.widgets = (1...3).map { widget("\($0)") }
        weak var opened: WidgetSpotPicker?
        try autoreleasepool {
            try openPicker()
            opened = view.spotPicker
            #expect(opened != nil)
            press(kVK_Escape, "\u{1B}")
        }
        #expect(view.spotPicker == nil)
        #expect(opened == nil)
    }

    private func openPicker() throws {
        view.layoutSubtreeIfNeeded()
        view.selectWidget(0)
        press(kVK_ANSI_K, "k", [.command])
        let menu = try #require(view.actionPanel)
        #expect(menu.rows[1].accessibilityPerformPress())
    }

    private func widget(_ id: String, wide: Bool = false) -> WidgetGrid.Widget {
        .init(
            id: id, name: id, content: .value(id, detail: ""), action: "Open \(id)", spoken: id,
            isWide: wide)
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
}
