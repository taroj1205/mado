import AppCore
import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct ModifierKeycapsTests {
    @Test func hyperShowsFourKeycapsInMenuOrder() {
        let keycaps = ModifierKeycaps([.command, .shift, .option, .control])
        let keys = keycaps.arrangedSubviews.compactMap { ($0 as? Keycap)?.name.stringValue }
        #expect(keys == ["⌃", "⌥", "⇧", "⌘"])
        #expect(keycaps.isAccessibilityElement())
        #expect(keycaps.accessibilityValue() as? String == "Control Option Shift Command")
    }
}
