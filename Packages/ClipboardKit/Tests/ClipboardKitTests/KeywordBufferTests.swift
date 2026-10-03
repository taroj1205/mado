import Carbon.HIToolbox
import CoreGraphics
import Testing

@testable import ClipboardKit

@Suite struct KeywordBufferTests {
    private static let keywords = [#"\sig"#, ";fu", #"\s"#, ""]

    private static func type(_ text: String, into buffer: inout KeywordBuffer) -> [String] {
        text.compactMap { buffer.handle(.text(String($0)), keywords: keywords) }
    }

    @Test func matchesTheKeywordJustTyped() {
        var buffer = KeywordBuffer()

        #expect(Self.type("hello ;fu", into: &buffer) == [";fu"])
        #expect(buffer.typed.isEmpty)
        #expect(Self.type(";f", into: &buffer).isEmpty)
    }

    @Test func prefersTheLongestKeywordEndingHere() {
        var buffer = KeywordBuffer()

        #expect(Self.type(#"x\s"#, into: &buffer) == [#"\s"#])
        let overlapping = [#"\sig"#, "ig"]
        let matched = #"\sig"#.compactMap { character in
            buffer.handle(.text(String(character)), keywords: overlapping)
        }
        #expect(matched == [#"\sig"#])
    }

    @Test func followsBackspaceAndForgetsOnOtherKeys() {
        var buffer = KeywordBuffer()

        _ = Self.type(";fx", into: &buffer)
        _ = buffer.handle(.deleteBackward, keywords: Self.keywords)
        let corrected = Self.type("u", into: &buffer)
        _ = Self.type(";f", into: &buffer)
        _ = buffer.handle(.other, keywords: Self.keywords)
        let afterArrow = Self.type("u", into: &buffer)

        #expect(corrected == [";fu"])
        #expect(afterArrow.isEmpty)
    }

    @Test func keepsOnlyAsMuchAsTheLongestKeyword() {
        var buffer = KeywordBuffer()

        _ = Self.type("a very long sentence", into: &buffer)

        #expect(buffer.typed == "ence")
        var empty = KeywordBuffer()
        #expect(empty.handle(.text("a"), keywords: []) == nil)
    }

    @Test func readsTypedTextFromKeyEvents() throws {
        #expect(KeywordBuffer.key(for: try TestKeys.event(kVK_ANSI_S, "s", [])) == .text("s"))
        #expect(
            KeywordBuffer.key(for: try TestKeys.event(kVK_ANSI_E, "é", .maskAlternate))
                == .text("é"))
        #expect(
            KeywordBuffer.key(for: try TestKeys.event(kVK_Delete, "\u{7F}", [])) == .deleteBackward)
        #expect(
            KeywordBuffer.key(for: try TestKeys.event(kVK_Delete, "\u{7F}", .maskShift))
                == .deleteBackward)
        #expect(
            KeywordBuffer.key(for: try TestKeys.event(kVK_Delete, "\u{7F}", .maskAlternate))
                == .other)
        #expect(KeywordBuffer.key(for: try TestKeys.event(kVK_Return, "\r", [])) == .other)
        #expect(KeywordBuffer.key(for: try TestKeys.event(kVK_LeftArrow, "\u{F702}", [])) == .other)
        #expect(
            KeywordBuffer.key(for: try TestKeys.event(kVK_ANSI_V, "v", .maskCommand)) == .other)
        #expect(
            KeywordBuffer.key(for: try TestKeys.event(kVK_ANSI_A, "a", .maskControl)) == .other)
        #expect(KeywordBuffer.key(for: try TestKeys.event(kVK_F1, "", [])) == nil)
    }
}
