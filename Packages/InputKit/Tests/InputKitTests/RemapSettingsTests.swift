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
        #expect(!settings.tapSendsEscape)
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
        #expect(!hyper.tapSendsEscape)
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
        remaps.tapSendsEscape = true
        remaps.setApplies(false, to: Self.keychron)
        var settings = Settings()
        try settings.setValue(remaps, for: "remaps")
        #expect(try settings.value(RemapSettings.self, for: "remaps") == remaps)
    }
}
