import AppKit
import Carbon.HIToolbox
import InputKit
import Testing

@testable import ClipboardKit

@MainActor
@Suite struct PasteQueueTests {
    private static func clip(_ text: String) -> Clip {
        Clip(.text, text: text, type: nil, data: nil, source: nil, date: .now)
    }

    private static func pasteKey() -> Int {
        Int(KeyboardLayout.commandKeyCode(typing: "v") ?? CGKeyCode(kVK_ANSI_V))
    }

    @Test func pastesInTheOrderThingsWereCopied() {
        var queue = PasteQueue()
        for text in ["Taro Yamada", "12 Queen Street", "Auckland 1010"] {
            queue.add(Self.clip(text))
        }

        #expect(queue.next?.text == "Taro Yamada")
        queue.advance()
        #expect(queue.waiting.map(\.text) == ["12 Queen Street", "Auckland 1010"])
        #expect(queue.pasted.map(\.text) == ["Taro Yamada"])
        #expect(queue.next?.text == "12 Queen Street")
        queue.advance()
        queue.advance()
        #expect(queue.next == nil)
        queue.advance()
        #expect(queue.pasted.map(\.text) == ["Taro Yamada", "12 Queen Street", "Auckland 1010"])
    }

    @Test func readsCommandVAsPasteAndEscapeAsClear() throws {
        let paste = try TestKeys.event(Self.pasteKey(), "v", .maskCommand)
        let escape = try TestKeys.event(kVK_Escape, "\u{1b}", [])

        #expect(PasteQueue.key(for: paste) == .paste)
        #expect(PasteQueue.key(for: escape) == .clear)
    }

    @Test func leavesOtherKeysAlone() throws {
        let keys = [
            try TestKeys.event(Self.pasteKey(), "v", []),
            try TestKeys.event(Self.pasteKey(), "v", [.maskCommand, .maskShift]),
            try TestKeys.event(Self.pasteKey(), "v", [.maskCommand, .maskAlternate]),
            try TestKeys.event(kVK_Escape, "\u{1b}", .maskCommand),
            try TestKeys.event(kVK_ANSI_C, "c", .maskCommand),
        ]

        #expect(keys.allSatisfy { PasteQueue.key(for: $0) == nil })
    }

    @Test func ignoresPastesMadoPostsAndHeldKeys() throws {
        let posted = try #require(try PasteTarget.commandV().first)
        let held = try TestKeys.event(Self.pasteKey(), "v", .maskCommand)
        held.setIntegerValueField(.keyboardEventAutorepeat, value: 1)

        #expect(PasteQueue.key(for: posted) == nil)
        #expect(PasteQueue.key(for: held) == nil)
    }
}
