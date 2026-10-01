import AppCore
import Testing

@testable import GlassUI

@Suite struct HotkeyRecorderModelTests {
    private let space: UInt16 = 49

    @Test func startsWaiting() {
        #expect(HotkeyRecorderModel().state == .waiting)
    }

    @Test func capturesAChord() {
        var model = HotkeyRecorderModel()
        let modifiers: Shortcut.Modifiers = [.control, .option]
        let effect = model.keyDown(keyCode: space, modifiers: modifiers, keyName: "Space")
        let shortcut = Shortcut(keyCode: 49, modifiers: modifiers)
        #expect(effect == .recorded)
        #expect(model.state == .captured(.chord(shortcut, keyName: "Space")))
        #expect(model.capture?.keyCaps == ["⌃", "⌥", "Space"])
    }

    @Test func capturesASingleKey() {
        var model = HotkeyRecorderModel()
        model.keyDown(keyCode: 96, modifiers: [], keyName: "F5")
        #expect(model.capture?.keyCaps == ["F5"])
    }

    @Test func reportsAConflict() {
        var model = HotkeyRecorderModel { $0.keyCode == 49 ? "Spotlight" : nil }
        model.keyDown(keyCode: space, modifiers: .command, keyName: "Space")
        let shortcut = Shortcut(keyCode: 49, modifiers: .command)
        #expect(model.state == .conflict(.chord(shortcut, keyName: "Space"), owner: "Spotlight"))
        model.keyDown(keyCode: 0, modifiers: .command, keyName: "A")
        #expect(
            model.state
                == .captured(.chord(Shortcut(keyCode: 0, modifiers: .command), keyName: "A")))
    }

    @Test func escapeCancelsAndDeleteClears() {
        var model = HotkeyRecorderModel()
        model.keyDown(keyCode: space, modifiers: .command, keyName: "Space")
        #expect(model.keyDown(keyCode: 53, modifiers: [], keyName: "Esc") == .cancel)
        #expect(model.capture != nil)
        #expect(model.keyDown(keyCode: 51, modifiers: [], keyName: "⌫") == .clear)
        #expect(model.state == .waiting)
    }

    @Test func modifiedEscapeAndDeleteAreRecordedAsKeys() {
        var model = HotkeyRecorderModel()
        #expect(model.keyDown(keyCode: 51, modifiers: .command, keyName: "⌫") == .recorded)
        #expect(model.capture?.keyCaps == ["⌘", "⌫"])
        #expect(model.keyDown(keyCode: 53, modifiers: .shift, keyName: "Esc") == .recorded)
        #expect(model.capture?.keyCaps == ["⇧", "Esc"])
    }

    @Test func aLoneModifierTapIsCaptured() {
        var model = HotkeyRecorderModel()
        model.modifierDown(.rightCommand)
        #expect(model.state == .waiting)
        model.modifierUp(.rightCommand)
        #expect(model.state == .captured(.modifierTap(.rightCommand)))
        #expect(model.capture?.keyCaps == ["Right ⌘"])
    }

    @Test func leftAndRightAreSeparateKeys() {
        var model = HotkeyRecorderModel()
        model.modifierDown(.leftShift)
        model.modifierUp(.leftShift)
        #expect(model.capture == .modifierTap(.leftShift))
        #expect(model.capture != .modifierTap(.rightShift))
    }

    @Test func aModifierUsedInAChordIsNotATap() {
        var model = HotkeyRecorderModel()
        model.modifierDown(.leftCommand)
        model.keyDown(keyCode: 0, modifiers: .command, keyName: "A")
        model.modifierUp(.leftCommand)
        #expect(model.capture?.keyCaps == ["⌘", "A"])
    }

    @Test func twoModifiersAreNotATap() {
        var model = HotkeyRecorderModel()
        model.modifierDown(.leftCommand)
        model.modifierDown(.leftShift)
        model.modifierUp(.leftShift)
        model.modifierUp(.leftCommand)
        #expect(model.state == .waiting)
    }

    @Test func releasingModifiersForgetsAHeldKey() {
        var model = HotkeyRecorderModel()
        model.modifierDown(.leftCommand)
        model.releaseAllModifiers()
        model.modifierDown(.leftShift)
        model.modifierUp(.leftShift)
        #expect(model.capture == .modifierTap(.leftShift))
    }

    @Test func modifierKeyCodesMapToSides() {
        #expect(ModifierKey(keyCode: 54) == .rightCommand)
        #expect(ModifierKey(keyCode: 55) == .leftCommand)
        #expect(ModifierKey(keyCode: 49) == nil)
        #expect(Set(ModifierKey.allCases.map(\.deviceMask)).count == 8)
    }

    @Test func namesKeys() {
        #expect(HotkeyCapture.keyName(keyCode: 49, characters: " ") == "Space")
        #expect(HotkeyCapture.keyName(keyCode: 0, characters: "a") == "A")
        #expect(HotkeyCapture.keyName(keyCode: 200, characters: nil) == "Key 200")
    }
}
