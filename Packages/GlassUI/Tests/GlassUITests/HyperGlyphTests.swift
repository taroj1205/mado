import AppCore
import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite struct HyperGlyphTests {
    private static let hyperT = Shortcut(keyCode: UInt32(kVK_ANSI_T), modifiers: .hyper)

    private static func showingGlyph(_ body: () throws -> Void) rethrows {
        HyperGlyph.isShown = true
        defer { HyperGlyph.isShown = false }
        try body()
    }

    @Test func hyperShortcutsKeepAllFourSymbolsByDefault() {
        #expect(HotKeyLabel.keycaps(.shortcut(Self.hyperT)) == ["⌃", "⌥", "⇧", "⌘", "T"])
        #expect(HotKeyLabel.spoken(Self.hyperT) == "Control Option Shift Command T")
    }

    @Test func theGlyphStandsInForAllFourModifiers() {
        Self.showingGlyph {
            #expect(HotKeyLabel.keycaps(.shortcut(Self.hyperT)) == ["✦", "T"])
            let withFn = Shortcut(
                keyCode: UInt32(kVK_ANSI_T), modifiers: Shortcut.Modifiers.hyper.union(.function))
            #expect(HotKeyLabel.keycaps(.shortcut(withFn)) == ["fn", "✦", "T"])
            let threeOfFour = Shortcut(
                keyCode: UInt32(kVK_ANSI_T), modifiers: [.control, .option, .command])
            #expect(HotKeyLabel.keycaps(.shortcut(threeOfFour)) == ["⌃", "⌥", "⌘", "T"])
            #expect(HotKeyLabel.symbols(.hyper) == ["✦"])
        }
    }

    @Test func voiceOverHearsHyperInsteadOfTheGlyph() {
        Self.showingGlyph {
            #expect(HotKeyLabel.spoken(Self.hyperT) == "Hyper T")
            #expect(HotKeyLabel.spoken(.hyper) == "Hyper")
            #expect(
                HotKeyLabel.spoken(text: "Notes already uses ✦T.") == "Notes already uses Hyper T.")
            let button = HotKeyButton()
            button.shortcut = Self.hyperT
            #expect(button.accessibilityValue() as? String == "Hyper T")
        }
    }

    @Test func theHyperRowStillSpellsOutTheModifiers() {
        Self.showingGlyph {
            let keycaps = ModifierKeycaps(.hyper)
            let keys = keycaps.arrangedSubviews.compactMap { ($0 as? Keycap)?.name.stringValue }
            #expect(keys == ["⌃", "⌥", "⇧", "⌘"])
            #expect(keycaps.accessibilityValue() as? String == "Control Option Shift Command")
        }
    }
}
