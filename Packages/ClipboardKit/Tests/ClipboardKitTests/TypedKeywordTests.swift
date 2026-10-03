import Testing

@testable import ClipboardKit

@Suite struct TypedKeywordTests {
    @Test func findsTheKeywordJustBeforeTheCaret() {
        #expect(TypedKeyword(";fu", before: "x;fu", selecting: false) == .inPlace)
        #expect(TypedKeyword(";fu", before: ";fu", selecting: false) == .inPlace)
    }

    @Test func waitsWhileTheLastKeyHasNotReachedTheText() {
        #expect(TypedKeyword(";fu", before: "x;f", selecting: false) == .arriving)
    }

    @Test func notesAKeywordTheAppRewroteAsItWasTyped() {
        #expect(TypedKeyword("--sig", before: "a—sig", selecting: false) == .changed)
        #expect(TypedKeyword("--", before: "a—", selecting: false) == .changed)
    }

    @Test func leavesAKeywordFollowedBySelectedText() {
        #expect(TypedKeyword(";fu", before: "x;fu", selecting: true) == .changed)
        #expect(TypedKeyword(";fu", before: nil, selecting: true) == .changed)
    }

    @Test func cannotTellWhenTheAppDoesNotShareItsText() {
        #expect(TypedKeyword(";fu", before: nil, selecting: false) == .unreadable)
    }
}
