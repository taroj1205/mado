import AppCore
import Foundation
import Testing

@testable import InputKit

@Suite struct RemapSettingsTests {
    private static let keychron = Keyboard(
        name: "Keychron K3", vendorID: 0x05AC, productID: 0x024F, layout: .ansi)

    @Test func nothingIsRemappedByDefault() {
        let settings = RemapSettings()
        #expect(settings.capsLock == .capsLock)
        #expect(settings.tapAction == .nothing)
        #expect(settings.tapShortcut == nil)
        #expect(!settings.hyperAsGlyph)
        #expect(settings.tap == nil)
        #expect(!settings.showsHyperGlyph)
        #expect(settings.excludedKeyboards.isEmpty)
        #expect(settings.applies(to: Self.keychron))
    }

    @Test func missingKeysKeepTheirDefaults() throws {
        let decoded = try JSONDecoder().decode(
            RemapSettings.self, from: Data(#"{"capsLock": "caps_lock"}"#.utf8))
        #expect(decoded == RemapSettings())
        let hyper = try JSONDecoder().decode(
            RemapSettings.self, from: Data(#"{"capsLock": "hyper"}"#.utf8))
        #expect(hyper.capsLock == .hyper)
        #expect(hyper.tapAction == .nothing)
    }

    @Test(arguments: [(true, RemapSettings.TapAction.escape), (false, .nothing)])
    func escapeSwitchBecomesATapAction(_ isOn: Bool, _ action: RemapSettings.TapAction) throws {
        let json = #"{"capsLock": "hyper", "tapSendsEscape": \#(isOn)}"#
        let decoded = try JSONDecoder().decode(RemapSettings.self, from: Data(json.utf8))
        #expect(decoded.tapAction == action)
        let saved = try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded))
        #expect((saved as? [String: Any])?["tapSendsEscape"] == nil)
        #expect((saved as? [String: Any])?["tapAction"] as? String == action.rawValue)
    }

    @Test func aChosenTapActionWinsOverTheOldEscapeSwitch() throws {
        let json = #"{"tapSendsEscape": true, "tapAction": "open_mado"}"#
        let decoded = try JSONDecoder().decode(RemapSettings.self, from: Data(json.utf8))
        #expect(decoded.tapAction == .openMado)
    }

    @Test(arguments: RemapSettings.CapsLock.allCases)
    func aTapRunsOnlyWhenCapsLockIsHeldAsAModifier(_ capsLock: RemapSettings.CapsLock) {
        var settings = RemapSettings()
        settings.capsLock = capsLock
        settings.tapAction = .capsLock
        #expect((settings.tap == .capsLock) == [.control, .hyper].contains(capsLock))
    }

    @Test func eachTapActionMapsToWhatATapDoes() {
        var settings = RemapSettings()
        settings.capsLock = .control
        let shortcut = Shortcut(keyCode: 17, modifiers: .hyper)
        settings.tapShortcut = shortcut
        let taps = RemapSettings.TapAction.allCases.map { action in
            settings.tapAction = action
            return settings.tap
        }
        #expect(taps == [nil, .escape, .capsLock, .openMado, .toggleMado, .shortcut(shortcut)])
    }

    @Test func aShortcutTapNeedsARecordedShortcut() {
        var settings = RemapSettings()
        settings.capsLock = .hyper
        settings.tapAction = .shortcut
        #expect(settings.tap == nil)
    }

    @Test(arguments: RemapSettings.CapsLock.allCases)
    func theHyperGlyphShowsOnlyWhileCapsLockIsHyper(_ capsLock: RemapSettings.CapsLock) {
        var settings = RemapSettings()
        settings.capsLock = capsLock
        #expect(!settings.showsHyperGlyph)
        settings.hyperAsGlyph = true
        #expect(settings.showsHyperGlyph == (capsLock == .hyper))
    }

    @Test func aKeyboardCanBeTurnedOffAndOnAgain() {
        var settings = RemapSettings()
        settings.setApplies(false, to: Self.keychron)
        settings.setApplies(false, to: Self.keychron)
        #expect(settings.excludedKeyboards == [Self.keychron])
        #expect(!settings.applies(to: Self.keychron))
        settings.setApplies(true, to: Self.keychron)
        #expect(settings.excludedKeyboards.isEmpty)
    }

    @Test func savedRemapsSurviveARoundTrip() throws {
        var remaps = RemapSettings()
        remaps.capsLock = .hyper
        remaps.tapAction = .shortcut
        remaps.tapShortcut = Shortcut(keyCode: 17, modifiers: .hyper)
        remaps.hyperAsGlyph = true
        remaps.setApplies(false, to: Self.keychron)
        var settings = Settings()
        try settings.setValue(remaps, for: "remaps")
        #expect(try settings.value(RemapSettings.self, for: "remaps") == remaps)
    }
}
