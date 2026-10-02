import Carbon.HIToolbox
import Testing

@testable import InputKit

@MainActor
@Suite struct KeyboardLayoutTests {
    private static func layout(_ id: String) throws -> TISInputSource {
        let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
        let sources =
            unsafe TISCreateInputSourceList(filter, true)?.takeRetainedValue()
            as? [TISInputSource] ?? []
        return try #require(sources.first)
    }

    @Test(arguments: [
        ("com.apple.keylayout.US", kVK_ANSI_V),
        ("com.apple.keylayout.Dvorak", kVK_ANSI_Period),
        ("com.apple.keylayout.DVORAK-QWERTYCMD", kVK_ANSI_V),
    ])
    func findsTheKeyThatTypesVWithCommand(id: String, expected: Int) throws {
        let code = KeyboardLayout.commandKeyCode(typing: "v", in: try Self.layout(id))

        #expect(code == CGKeyCode(expected))
    }
}
