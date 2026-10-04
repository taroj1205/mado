import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite struct LauncherPendingResultsTests {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 476),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let view = LauncherView()

    init() {
        panel.contentView = view
        view.results.reducesMotion = { true }
        view.show([results("Safari", "Notes")])
        view.actions = { item in
            [.init("Open", keys: ["↵"]), .init("Show in Finder", keys: ["⌘", "↵"])]
                + (item.id == "Notes" ? [.init("Show Info", keys: ["⌘", "I"])] : [])
        }
        view.actionKeys = [["⌘", "I"]]
        panel.makeFirstResponder(view.field)
    }

    @Test func keysPressedBeforeTheResultsArriveRunOnThem() {
        var runs: [String] = []
        view.onRun = { runs.append("\($0.id) \($1)") }
        press(kVK_ANSI_N, "n")
        press(kVK_Return, "\r")
        #expect(runs.isEmpty)
        view.show([results("Notes")])
        #expect(runs == ["Notes 0"])

        press(kVK_ANSI_O, "o")
        press(kVK_Return, "\r", [.command])
        #expect(runs == ["Notes 0"])
        view.show([results("Notes")])
        #expect(runs == ["Notes 0", "Notes 1"])
    }

    @Test func typingAgainDropsTheKeyThatWasWaiting() {
        var runs: [String] = []
        view.onRun = { runs.append("\($0.id) \($1)") }
        press(kVK_ANSI_N, "n")
        press(kVK_Return, "\r")
        press(kVK_ANSI_O, "o")
        view.show([results("Notes")])
        #expect(runs.isEmpty)
    }

    @Test func anActionKeyWaitsEvenWhenTheShownRowLacksIt() {
        var runs: [String] = []
        view.onRun = { runs.append("\($0.id) \($1)") }
        press(kVK_ANSI_N, "n")
        press(kVK_ANSI_I, "i", [.command])
        #expect(runs.isEmpty)
        view.show([results("Notes")])
        #expect(runs == ["Notes 2"])
    }

    @Test func aWidgetPickedBeforeTheResultsArriveIsLetGo() {
        var runs: [String] = []
        view.onRun = { runs.append("\($0.id) \($1)") }
        view.widgets = [
            .init(
                id: "clock", name: "Clock", value: "9:41", detail: "Wed 30 Sep",
                action: "Open Clock", spoken: "Time: 9:41 AM, Wednesday 30 September")
        ]
        press(kVK_ANSI_N, "n")
        press(kVK_UpArrow, "\u{F700}")
        #expect(view.selectedWidget == 0)
        view.show([results("Notes")])
        #expect(view.selectedWidget == nil)
        press(kVK_Return, "\r")
        #expect(runs == ["Notes 0"])
    }

    private func results(_ titles: String...) -> ResultList.Section {
        .init(
            title: "Results",
            items: titles.map { title in
                .init(
                    id: title, title: title, subtitle: "", kind: "Command", symbol: "star",
                    action: "Open")
            })
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
