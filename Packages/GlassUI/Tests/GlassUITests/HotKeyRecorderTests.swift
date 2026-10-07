import AppCore
import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite struct HotKeyRecorderTests {
    static let commandSpace = HotKey.shortcut(
        Shortcut(keyCode: UInt32(kVK_Space), modifiers: .command))

    func event(
        _ type: NSEvent.EventType, _ keyCode: Int, _ flags: NSEvent.ModifierFlags
    ) throws -> NSEvent {
        try #require(
            NSEvent.keyEvent(
                with: type, location: .zero, modifierFlags: flags, timestamp: 0,
                windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
                isARepeat: false, keyCode: UInt16(keyCode)))
    }

    func heldDelete() throws -> NSEvent {
        try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
                isARepeat: true, keyCode: UInt16(kVK_Delete)))
    }

    func descendant<View: NSView>(_ type: View.Type, in view: NSView) -> View? {
        for child in view.subviews {
            if let match = child as? View ?? descendant(type, in: child) {
                return match
            }
        }
        return nil
    }

    @Test func recordsAChord() throws {
        let recorder = HotKeyRecorder()
        recorder.keyDown(with: try event(.keyDown, kVK_Space, [.control, .option]))
        let chord = HotKey.shortcut(
            Shortcut(keyCode: UInt32(kVK_Space), modifiers: [.control, .option]))
        #expect(recorder.state == .captured(chord))
        #expect(HotKeyLabel.keycaps(chord) == ["⌃", "⌥", "Space"])
    }

    @Test func recordsASingleKey() throws {
        let recorder = HotKeyRecorder()
        recorder.keyDown(with: try event(.keyDown, kVK_F5, []))
        #expect(
            recorder.state == .captured(.shortcut(Shortcut(keyCode: UInt32(kVK_F5), modifiers: [])))
        )
    }

    @Test func recordsAModifierTapWithItsSide() throws {
        let recorder = HotKeyRecorder()
        recorder.flagsChanged(with: try event(.flagsChanged, kVK_RightCommand, .command))
        recorder.flagsChanged(with: try event(.flagsChanged, kVK_RightCommand, []))
        #expect(recorder.state == .captured(.modifierTap(.rightCommand)))
        #expect(HotKeyLabel.keycaps(.modifierTap(.rightCommand)) == ["Right ⌘"])
        #expect(HotKeyLabel.keycaps(.modifierTap(.leftOption)) == ["Left ⌥"])
    }

    @Test func modifierFollowedByAKeyIsAChordNotATap() throws {
        let recorder = HotKeyRecorder()
        recorder.flagsChanged(with: try event(.flagsChanged, kVK_Option, .option))
        recorder.keyDown(with: try event(.keyDown, kVK_ANSI_S, .option))
        recorder.flagsChanged(with: try event(.flagsChanged, kVK_Option, []))
        #expect(
            recorder.state
                == .captured(.shortcut(Shortcut(keyCode: UInt32(kVK_ANSI_S), modifiers: .option))))
    }

    @Test func twoModifiersTogetherAreNotATap() throws {
        let recorder = HotKeyRecorder()
        recorder.flagsChanged(with: try event(.flagsChanged, kVK_Command, .command))
        recorder.flagsChanged(with: try event(.flagsChanged, kVK_Option, [.command, .option]))
        recorder.flagsChanged(with: try event(.flagsChanged, kVK_Option, .command))
        recorder.flagsChanged(with: try event(.flagsChanged, kVK_Command, []))
        #expect(recorder.state == .waiting)
    }

    @Test func namesTheSystemConflictAndCanStillSave() throws {
        let recorder = HotKeyRecorder()
        var saved: [HotKey] = []
        recorder.systemConflict = { $0 == Self.commandSpace ? "Spotlight" : nil }
        recorder.onSave = { hotKey in
            saved.append(hotKey)
            return nil
        }
        recorder.keyDown(with: try event(.keyDown, kVK_Space, .command))
        #expect(recorder.state == .conflict(Self.commandSpace, "Spotlight"))
        recorder.keyDown(with: try event(.keyDown, kVK_Return, []))
        #expect(saved == [Self.commandSpace])
    }

    @Test func escapeCancelsDeleteClearsReturnSaves() throws {
        let recorder = HotKeyRecorder()
        var cancelled = 0
        var saved: [HotKey] = []
        recorder.onCancel = { cancelled += 1 }
        recorder.onSave = { hotKey in
            saved.append(hotKey)
            return nil
        }
        recorder.keyDown(with: try event(.keyDown, kVK_Return, []))
        #expect(saved.isEmpty)
        recorder.keyDown(with: try event(.keyDown, kVK_Space, .command))
        recorder.keyDown(with: try event(.keyDown, kVK_Delete, []))
        #expect(recorder.state == .waiting)
        recorder.keyDown(with: try event(.keyDown, kVK_Escape, []))
        #expect(cancelled == 1)
        recorder.keyDown(with: try event(.keyDown, kVK_Return, .command))
        #expect(
            recorder.state
                == .captured(.shortcut(Shortcut(keyCode: UInt32(kVK_Return), modifiers: .command))))
    }

    @Test func deleteClearsTheSavedKeyOnlyWhenNothingIsPending() throws {
        let recorder = HotKeyRecorder()
        var cleared = 0
        recorder.onClear = { cleared += 1 }
        recorder.keyDown(with: try event(.keyDown, kVK_F5, []))
        recorder.keyDown(with: try event(.keyDown, kVK_Delete, []))
        #expect(recorder.state == .waiting)
        #expect(cleared == 0)
        recorder.keyDown(with: try heldDelete())
        #expect(cleared == 0)
        recorder.keyDown(with: try event(.keyDown, kVK_Delete, []))
        #expect(cleared == 1)
    }

    @Test func deleteDoesNothingWhenThereIsNothingToClear() throws {
        let recorder = HotKeyRecorder()
        recorder.keyDown(with: try event(.keyDown, kVK_Delete, []))
        #expect(recorder.state == .waiting)
    }

    @Test func takesMenuKeyEquivalentsOnlyWhileFocused() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 160), styleMask: [.titled],
            backing: .buffered, defer: true)
        let recorder = HotKeyRecorder()
        window.contentView = recorder
        let commandQ = try event(.keyDown, kVK_ANSI_Q, .command)
        #expect(!recorder.performKeyEquivalent(with: commandQ))
        window.makeFirstResponder(recorder)
        #expect(recorder.performKeyEquivalent(with: commandQ))
        #expect(
            recorder.state
                == .captured(.shortcut(Shortcut(keyCode: UInt32(kVK_ANSI_Q), modifiers: .command))))
        window.makeFirstResponder(nil)
    }

    @Test func turnsOffSystemShortcutsOnlyWhileFocused() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 160), styleMask: [.titled],
            backing: .buffered, defer: true)
        let recorder = HotKeyRecorder()
        window.contentView = recorder
        let before = GetSymbolicHotKeyMode()
        window.makeFirstResponder(recorder)
        #expect(
            GetSymbolicHotKeyMode() == OptionBits(kHIHotKeyModeAllDisabledExceptUniversalAccess))
        window.makeFirstResponder(nil)
        #expect(GetSymbolicHotKeyMode() == before)
        window.makeFirstResponder(recorder)
        recorder.removeFromSuperview()
        #expect(GetSymbolicHotKeyMode() == before)
    }

    @Test func pressingOrClickingTheFieldStartsRecording() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 160), styleMask: [.titled],
            backing: .buffered, defer: true)
        let recorder = HotKeyRecorder()
        window.contentView = recorder
        window.layoutIfNeeded()
        let field = try #require(descendant(HotKeyField.self, in: recorder))
        #expect(field.accessibilityRole() == .button)
        #expect(field.accessibilityPerformPress())
        #expect(window.firstResponder === recorder)

        window.makeFirstResponder(nil)
        let prompt = try #require(descendant(NSTextField.self, in: field))
        prompt.mouseDown(
            with: try #require(
                NSEvent.mouseEvent(
                    with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 0,
                    windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1,
                    pressure: 1)))
        #expect(window.firstResponder === recorder)
        window.makeFirstResponder(nil)
    }

    @Test func namesKeysFromTheKeyboardLayout() {
        #expect(HotKeyLabel.keyName(UInt32(kVK_F12)) == "F12")
        #expect(HotKeyLabel.keyName(UInt32(kVK_JIS_Eisu)) == "英数")
        #expect(HotKeyLabel.keyName(UInt32(kVK_ANSI_A)).count == 1)
    }

    @Test func spellsShortcutsOutForVoiceOver() {
        let all: Shortcut.Modifiers = [.command, .shift, .option, .control]
        #expect(
            HotKeyLabel.spoken(Shortcut(keyCode: UInt32(kVK_LeftArrow), modifiers: all))
                == "Control Option Shift Command Left Arrow")
        #expect(
            HotKeyLabel.spoken(Shortcut(keyCode: UInt32(kVK_Return), modifiers: [.command]))
                == "Command Return")
        #expect(
            HotKeyLabel.spoken(Shortcut(keyCode: UInt32(kVK_Space), modifiers: [.option]))
                == "Option Space")
        #expect(HotKeyLabel.spoken(Shortcut(keyCode: UInt32(kVK_F5), modifiers: [])) == "F5")
    }

    @Test func resetStartsOverAndClearShowsOnlyWhenAsked() throws {
        let recorder = HotKeyRecorder()
        recorder.keyDown(with: try event(.keyDown, kVK_F5, []))
        recorder.reset()
        #expect(recorder.state == .waiting)
        #expect(descendant(NSButton.self, in: recorder) == nil)

        var cleared = 0
        recorder.onClear = { cleared += 1 }
        let clear = try #require(descendant(NSButton.self, in: recorder))
        #expect(clear.title == "Clear")
        clear.performClick(nil)
        #expect(cleared == 1)
    }

    @Test func aHotKeyButtonShowsAModifierTapWithItsSide() {
        let button = HotKeyButton()
        button.hotKey = .modifierTap(.rightCommand)
        #expect(button.accessibilityValue() as? String == "Right ⌘ tap")
        #expect(button.shortcut == nil)

        button.shortcut = Shortcut(keyCode: UInt32(kVK_ANSI_S), modifiers: .option)
        #expect(
            button.hotKey == .shortcut(Shortcut(keyCode: UInt32(kVK_ANSI_S), modifiers: .option)))
        #expect(button.accessibilityValue() as? String == "⌥ S")
    }

    @Test func aRefusedSaveKeepsTheRecorderOpenWithTheReason() throws {
        let recorder = HotKeyRecorder()
        let reason = "macOS wouldn’t register this hotkey. Try another."
        var attempts = 0
        recorder.onSave = { _ in
            attempts += 1
            return reason
        }
        recorder.keyDown(with: try event(.keyDown, kVK_Space, .command))
        recorder.keyDown(with: try event(.keyDown, kVK_Return, []))
        #expect(recorder.state == .refused(Self.commandSpace, reason))
        recorder.keyDown(with: try event(.keyDown, kVK_Return, []))
        #expect(attempts == 1)
    }
}
