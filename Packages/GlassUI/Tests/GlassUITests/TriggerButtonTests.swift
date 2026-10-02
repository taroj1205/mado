import AppCore
import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite struct TriggerButtonTests {
    private let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 240, height: 80), styleMask: [.titled],
        backing: .buffered, defer: true)
    private let button = TriggerButton()

    init() {
        window.contentView = button
        button.modifiers = .function
    }

    private func flags(_ keyCode: Int, _ flags: NSEvent.ModifierFlags) throws -> NSEvent {
        try #require(
            NSEvent.keyEvent(
                with: .flagsChanged, location: .zero, modifierFlags: flags, timestamp: 0,
                windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
                isARepeat: false, keyCode: UInt16(keyCode)))
    }

    private func escape() throws -> NSEvent {
        try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: 0, context: nil, characters: "\u{1b}",
                charactersIgnoringModifiers: "\u{1b}", isARepeat: false,
                keyCode: UInt16(kVK_Escape)))
    }

    @Test func pressingStartsRecordingAndNamesTheTrigger() {
        #expect(button.accessibilityLabel() == "Trigger: hold fn. Click to record a new trigger")
        #expect(button.accessibilityPerformPress())
        #expect(button.isRecording)
        #expect(button.accessibilityLabel()?.hasPrefix("Recording trigger") == true)
    }

    @Test func savesEveryModifierHeldOnceAllAreReleased() throws {
        var saved: [Shortcut.Modifiers] = []
        button.onChange = { saved.append($0) }
        window.makeFirstResponder(button)

        button.flagsChanged(with: try flags(kVK_Command, .command))
        button.flagsChanged(with: try flags(kVK_Shift, [.command, .shift]))
        button.flagsChanged(with: try flags(kVK_Command, .shift))
        #expect(button.held == [.command, .shift])
        button.flagsChanged(with: try flags(kVK_Shift, []))

        #expect(saved == [[.command, .shift]])
        #expect(button.modifiers == [.command, .shift])
        #expect(!button.isRecording)
    }

    @Test func recordsFnAloneAndShowsItAsAKeycap() throws {
        var saved: [Shortcut.Modifiers] = []
        button.onChange = { saved.append($0) }
        window.makeFirstResponder(button)
        button.flagsChanged(with: try flags(kVK_Function, .function))
        button.flagsChanged(with: try flags(kVK_Function, []))

        window.makeFirstResponder(button)
        button.flagsChanged(with: try flags(kVK_Control, .control))
        button.flagsChanged(with: try flags(kVK_Control, []))

        #expect(saved == [.function, .control])
        #expect(
            HotKeyLabel.keycaps(.shortcut(Shortcut(keyCode: 0, modifiers: [.function, .control])))
                .prefix(2) == ["fn", "⌃"])
        #expect(!button.isRecording)
    }

    @Test func escapeCancelsAndKeepsTheTrigger() throws {
        var saved: [Shortcut.Modifiers] = []
        button.onChange = { saved.append($0) }
        window.makeFirstResponder(button)

        button.flagsChanged(with: try flags(kVK_Command, .command))
        button.keyDown(with: try escape())

        #expect(!button.isRecording)
        #expect(saved.isEmpty)
        #expect(button.modifiers == .function)
    }
}
