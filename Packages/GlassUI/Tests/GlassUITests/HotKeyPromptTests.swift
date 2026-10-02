import AppCore
import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite(.serialized) final class HotKeyPromptTests {
    private let window = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 300, height: 200), styleMask: [.titled],
        backing: .buffered, defer: false)
    private let prompt = HotKeyPrompt()
    private let optionS = Shortcut(keyCode: UInt32(kVK_ANSI_S), modifiers: .option)
    private var saved: [Shortcut] = []
    private var problem: String?
    private var cleared = 0
    private var cancelled = 0

    init() {
        window.contentView = prompt
        prompt.onSave = { [weak self] shortcut in
            self?.saved.append(shortcut)
            return self?.problem
        }
        prompt.onClear = { [weak self] in self?.cleared += 1 }
        prompt.onCancel = { [weak self] in self?.cancelled += 1 }
    }

    @Test func savesAChordAndShowsHeldModifiersWhileWaiting() {
        prompt.show(for: "Notes", clearable: true)
        #expect(prompt.title.stringValue == "Press a shortcut for Notes")
        #expect(prompt.field.accessibilityValue() as? String == "Press keys…")

        send(.flagsChanged, kVK_Option, .option)
        #expect(prompt.field.accessibilityValue() as? String == "⌥ + key")
        send(.keyDown, kVK_ANSI_S, .option)
        #expect(saved == [optionS])
    }

    @Test func aConflictStaysOnScreenAndDoesNotSave() {
        prompt.conflict = { [optionS] in $0 == optionS ? "Safari" : nil }
        prompt.show(for: "Notes", clearable: false)

        send(.keyDown, kVK_ANSI_S, .option)
        send(.flagsChanged, kVK_Option, [])
        #expect(saved.isEmpty)
        #expect(!prompt.warning.isHidden)
        #expect(prompt.warning.stringValue == "Safari already uses ⌥S.")

        send(.flagsChanged, kVK_Control, .control)
        #expect(prompt.warning.isHidden)
    }

    @Test func savingStopsRecordingFirstAndARefusalRecordsAgain() {
        var recording: [Bool] = []
        prompt.onRecording = { recording.append($0) }
        problem = "macOS wouldn’t register this hotkey. Try another."
        prompt.show(for: "Notes", clearable: false)

        send(.keyDown, kVK_ANSI_S, .option)
        #expect(saved == [optionS])
        #expect(recording == [true, false, true])
        #expect(prompt.warning.stringValue == problem)
        #expect(window.firstResponder === prompt)
    }

    @Test func plainKeysCancelOrClearButNeverSave() {
        prompt.show(for: "Notes", clearable: false)
        send(.keyDown, kVK_ANSI_S, .shift)
        send(.keyDown, kVK_Delete, [], "\u{7F}")
        #expect(saved.isEmpty)
        #expect(cleared == 0)
        #expect(!prompt.clear.isEnabled)

        prompt.show(for: "Notes", clearable: true)
        send(.keyDown, kVK_Delete, [], "\u{7F}")
        send(.keyDown, kVK_Escape, [], "\u{1B}")
        prompt.cancel.performClick(nil)
        #expect(cleared == 1)
        #expect(cancelled == 2)
    }

    @Test func layoutFollowsTheCanvas() {
        prompt.show(for: "Notes", clearable: true)
        prompt.layoutSubtreeIfNeeded()
        let title = prompt.convert(prompt.title.bounds, from: prompt.title)
        let clear = prompt.convert(prompt.clear.bounds, from: prompt.clear)
        let cancel = prompt.convert(prompt.cancel.bounds, from: prompt.cancel)

        #expect(prompt.frame.width == 300)
        #expect(prompt.field.frame.height == 44)
        #expect(title.minX < 20)
        #expect(clear.minX < 30)
        #expect(cancel.maxX > 270)
        #expect(!prompt.hasAmbiguousLayout)
    }

    @Test func recordingLastsWhileThePromptHasFocus() {
        var recording: [Bool] = []
        prompt.onRecording = { recording.append($0) }
        window.makeFirstResponder(prompt)
        window.makeFirstResponder(nil)
        #expect(recording == [true, false])

        window.makeFirstResponder(prompt)
        window.contentView = nil
        #expect(recording == [true, false, true, false])
    }

    @Test func aPressButtonHandsClicksBackAndShowsRecording() {
        let button = HotKeyButton()
        var presses = 0
        button.onPress = { presses += 1 }
        button.shortcut = optionS
        window.contentView = button

        #expect(button.accessibilityPerformPress())
        #expect(presses == 1)
        #expect(window.firstResponder !== button)
        #expect(button.accessibilityValue() as? String == "⌥ S")

        button.showsRecording = true
        #expect(button.accessibilityValue() as? String == "Recording…")
        button.showsRecording = false
        #expect(button.accessibilityValue() as? String == "⌥ S")
    }

    private func send(
        _ type: NSEvent.EventType, _ keyCode: Int, _ modifiers: NSEvent.ModifierFlags,
        _ characters: String = ""
    ) {
        window.makeFirstResponder(prompt)
        guard
            let event = NSEvent.keyEvent(
                with: type, location: .zero, modifierFlags: modifiers, timestamp: 0,
                windowNumber: window.windowNumber, context: nil, characters: characters,
                charactersIgnoringModifiers: characters, isARepeat: false,
                keyCode: UInt16(keyCode))
        else {
            Issue.record("Could not make a key event for \(keyCode)")
            return
        }
        if type == .flagsChanged {
            prompt.flagsChanged(with: event)
        } else {
            prompt.keyDown(with: event)
        }
    }

    isolated deinit {
        window.makeFirstResponder(nil)
    }
}
