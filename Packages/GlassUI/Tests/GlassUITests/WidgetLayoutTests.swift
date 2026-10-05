import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetLayoutTests {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 548),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let view = LauncherView()

    init() {
        panel.contentView = view
        view.results.sections = [.init(title: "Commands", items: [item("Safari")])]
        view.widgets = (1...7).map(numbered)
        panel.makeFirstResponder(view.field)
    }

    @Test func theStripIsOneRowOfShorterTilesAndLeavesOutTheRest() {
        view.layoutSubtreeIfNeeded()
        #expect(view.widgetGrid.tiles.count == 7)
        #expect(abs(view.widgetGrid.frame.height - (12 + 78 + 8 + 78 + 4)) < 0.01)
        view.selectWidget(6)
        view.widgetLayout = .strip
        view.layoutSubtreeIfNeeded()
        #expect(view.selectedWidget == nil)
        #expect(!view.results.hidesSelection)
        #expect(view.widgetGrid.tiles.count == 6)
        #expect(view.widgetGrid.tiles.allSatisfy { $0.frame.height == 72 })
        #expect(abs(view.widgetGrid.frame.height - (12 + 72 + 4)) < 0.01)
        press(kVK_UpArrow, "\u{F700}")
        for _ in 1...7 {
            press(kVK_RightArrow, "\u{F703}")
        }
        #expect(view.selectedWidget == 5)
        #expect(view.actionLabel.stringValue == "Open 6")
        view.widgetLayout = .grid
        #expect(view.widgetGrid.tiles.count == 7)
        #expect(view.selectedWidget == 5)
    }

    @Test func withoutALayoutTheWidgetsAreHiddenAndUpStaysInTheList() {
        view.selectWidget(1)
        view.widgetLayout = nil
        view.layoutSubtreeIfNeeded()
        #expect(view.selectedWidget == nil)
        #expect(view.widgetGrid.isHidden)
        #expect(view.widgetGrid.frame.height == 0)
        press(kVK_UpArrow, "\u{F700}")
        #expect(view.selectedWidget == nil)
        #expect(view.results.selectedItem?.id == "Safari")
        view.widgetLayout = .grid
        #expect(!view.widgetGrid.isHidden)
        #expect(view.widgetGrid.tiles.count == 7)
    }

    private func numbered(_ number: Int) -> WidgetGrid.Widget {
        .init(
            id: "\(number)", name: "Widget \(number)", value: "\(number)", detail: "",
            action: "Open \(number)",
            spoken: "Widget \(number)")
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
}
