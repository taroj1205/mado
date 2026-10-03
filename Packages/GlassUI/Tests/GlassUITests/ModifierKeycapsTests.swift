import AppCore
import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct ModifierKeycapsTests {
    @Test func showsOneKeycapPerModifierInMenuOrderAndSpeaksTheirNames() {
        let keycaps = ModifierKeycaps([.command, .shift, .option, .control])
        let names = keycaps.views.compactMap { ($0 as? Keycap)?.name.stringValue }
        #expect(names == ["⌃", "⌥", "⇧", "⌘"])
        #expect(keycaps.accessibilityValue() as? String == "Control Option Shift Command")
    }
}
