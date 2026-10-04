import Foundation
import Testing

@testable import AppCore

@Suite struct ShortcutTests {
    @Test func roundTripsThroughJSON() throws {
        let shortcut = Shortcut(keyCode: 49, modifiers: [.command, .shift])
        let decoded = try JSONDecoder().decode(
            Shortcut.self, from: JSONEncoder().encode(shortcut))
        #expect(decoded == shortcut)
    }

    @Test func differentModifiersAreDifferentShortcuts() {
        let plain = Shortcut(keyCode: 49, modifiers: [.command])
        let shifted = Shortcut(keyCode: 49, modifiers: [.command, .shift])
        #expect(plain != shifted)
        #expect(Set([plain, shifted, plain]).count == 2)
    }

    @Test func storesAModifierTapByItsSide() throws {
        let data = try JSONEncoder().encode(HotKey.modifierTap(.rightCommand))
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json == #"{"modifier_tap":"right_command"}"#)
        #expect(try JSONDecoder().decode(HotKey.self, from: data) == .modifierTap(.rightCommand))
    }

    @Test func storesAShortcutHotKey() throws {
        let hotKey = HotKey.shortcut(Shortcut(keyCode: 49, modifiers: [.control, .option]))
        let decoded = try JSONDecoder().decode(HotKey.self, from: JSONEncoder().encode(hotKey))

        #expect(decoded == hotKey)
    }
}
