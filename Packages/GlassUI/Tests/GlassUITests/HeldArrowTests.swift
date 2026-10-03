import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite struct HeldArrowTests {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 548),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let view = LauncherView()

    init() {
        panel.contentView = view
        view.results.reducesMotion = { true }
        view.results.sections = [
            .init(title: "Commands", items: ["Safari", "Notes", "Sleep"].map(item))
        ]
        view.widgets = [
            .init(
                id: "clock", value: "9:41", detail: "Wed 30 Sep", action: "Open Clock",
                spoken: "Time: 9:41 AM, Wednesday 30 September")
        ]
        view.pills = [
            .init(
                id: "uptime", name: "Uptime", symbol: "clock", value: "17h",
                action: "Show System Report")
        ]
        panel.makeFirstResponder(view.field)
    }

    @Test func aHeldDownArrowStopsAtTheLastRowAndAFreshPressEntersThePills() {
        for _ in 0..<5 {
            press(kVK_DownArrow, "\u{F701}", repeating: true)
        }
        #expect(view.selectedPill == nil)
        #expect(view.results.selectedItem?.id == "Sleep")
        press(kVK_DownArrow, "\u{F701}", repeating: false)
        #expect(view.selectedPill == 0)
        press(kVK_DownArrow, "\u{F701}", repeating: true)
        #expect(view.selectedPill == 0)
        press(kVK_UpArrow, "\u{F700}", repeating: true)
        #expect(view.selectedPill == nil)
        #expect(view.results.selectedItem?.id == "Sleep")
    }

    @Test func aHeldUpArrowStopsAtTheFirstRowAndAFreshPressEntersTheWidgets() {
        press(kVK_DownArrow, "\u{F701}", repeating: false)
        for _ in 0..<5 {
            press(kVK_UpArrow, "\u{F700}", repeating: true)
        }
        #expect(view.selectedWidget == nil)
        #expect(view.results.selectedItem?.id == "Safari")
        press(kVK_UpArrow, "\u{F700}", repeating: false)
        #expect(view.selectedWidget == 0)
    }

    @Test func aHeldDownArrowFromTheWidgetsCarriesOnDownTheList() {
        press(kVK_UpArrow, "\u{F700}", repeating: false)
        press(kVK_DownArrow, "\u{F701}", repeating: true)
        press(kVK_DownArrow, "\u{F701}", repeating: true)
        #expect(view.selectedWidget == nil)
        #expect(view.results.selectedItem?.id == "Notes")
    }

    private func press(_ keyCode: Int, _ characters: String, repeating: Bool) {
        view.isKeyRepeat = { repeating }
        guard
            let event = NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, characters: characters,
                charactersIgnoringModifiers: characters, isARepeat: repeating,
                keyCode: UInt16(keyCode))
        else {
            Issue.record("Could not make a key event for \(keyCode)")
            return
        }
        panel.sendEvent(event)
    }

    private func item(_ title: String) -> ResultList.Item {
        .init(
            id: title, title: title, subtitle: "", kind: "Command", symbol: "star",
            action: "Run Command")
    }
}
