import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite(.serialized) final class ActionShortcutTests {
    private let panel = GlassPanel(
        kind: .panel, contentRect: NSRect(x: 100, y: 100, width: 760, height: 476),
        shape: .rounded(28))
    private let view = LauncherView()

    init() {
        panel.glass.contentView = view
        view.results.sections = [
            .init(
                title: "Results",
                items: [
                    .init(
                        id: "Terminal", title: "Terminal", subtitle: "", kind: "Application",
                        symbol: "star", action: "Open Application")
                ])
        ]
        view.actions = { _ in
            [
                .init("Open", keys: ["↵"]), .init("Create Quicklink", keys: ["⌘", "⇧", "L"]),
                .init("Show Info in Finder", keys: ["⌘", "I"]),
                .init("Paste as Plain Text", keys: LauncherView.Action.alternateKeys),
            ]
        }
        panel.makeFirstResponder(view.field)
    }

    @Test func anActionsShortcutRunsItWithOrWithoutThePanel() {
        var runs: [String] = []
        view.onRun = { runs.append("\($0.id) \($1)") }
        press(kVK_ANSI_L, "l", [.command])
        press(kVK_ANSI_L, "L", [.command, .shift, .option])
        #expect(runs.isEmpty)

        press(kVK_ANSI_L, "L", [.command, .shift])
        #expect(runs == ["Terminal 1"])

        press(kVK_ANSI_K, "k", [.command])
        #expect(view.choosingAction)
        press(kVK_ANSI_L, "L", [.command, .shift])
        #expect(runs == ["Terminal 1", "Terminal 1"])
        #expect(!view.choosingAction)

        press(kVK_ANSI_I, "i", [.command])
        #expect(runs == ["Terminal 1", "Terminal 1", "Terminal 2"])
    }

    @Test func optionReturnRunsTheActionKeyedToItWithOrWithoutThePanel() {
        var runs: [Int] = []
        view.onRun = { runs.append($1) }
        press(kVK_Return, "\r", [.option])
        #expect(runs == [3])

        press(kVK_ANSI_K, "k", [.command])
        #expect(view.choosingAction)
        press(kVK_Return, "\r", [.option])
        #expect(runs == [3, 3])
        #expect(!view.choosingAction)
        #expect(view.field.stringValue.isEmpty)
    }

    @Test func optionReturnDoesNothingWithoutAnActionKeyedToIt() {
        var runs: [Int] = []
        view.onRun = { runs.append($1) }
        view.actions = { _ in [.init("Open", keys: ["↵"])] }
        press(kVK_Return, "\r", [.option])
        press(kVK_ANSI_K, "k", [.command])
        press(kVK_Return, "\r", [.option])
        #expect(runs.isEmpty)
        #expect(view.choosingAction)
        #expect(view.field.stringValue.isEmpty)
    }

    private func press(_ keyCode: Int, _ characters: String, _ modifiers: NSEvent.ModifierFlags) {
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
        if panel.performKeyEquivalent(with: event) { return }
        panel.sendEvent(event)
    }

    isolated deinit {
        panel.makeFirstResponder(nil)
    }
}
