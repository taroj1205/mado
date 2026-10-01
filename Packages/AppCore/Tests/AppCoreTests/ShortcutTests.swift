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
}
