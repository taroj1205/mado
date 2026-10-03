import Testing

@testable import ClipboardKit

@Suite struct TypedKeywordTests {
    @Test func findsTheKeywordJustBeforeTheCaret() {
        #expect(TypedKeyword(";fu", before: "x;fu") == .inPlace)
        #expect(TypedKeyword(";fu", before: ";fu") == .inPlace)
    }

    @Test func waitsWhileTheLastKeyHasNotReachedTheText() {
        #expect(TypedKeyword(";fu", before: "x;f") == .arriving)
    }

    @Test func notesAKeywordTheAppRewroteAsItWasTyped() {
        #expect(TypedKeyword("--sig", before: "a—sig") == .changed)
        #expect(TypedKeyword("--", before: "a—") == .changed)
    }

    @Test func cannotTellWhenTheAppDoesNotShareItsText() {
        #expect(TypedKeyword(";fu", before: nil) == .unreadable)
    }
}
