import ApplicationServices
import Testing

@testable import WindowKit

@Suite struct FocusedTextTests {
    @Test func readsTheSelectionAndTheCaretBounds() throws {
        var selection = CFRange(location: 4, length: 0)
        var caret = CGRect(x: 120, y: 220, width: 0, height: 17)
        let range = try #require(unsafe AXValueCreate(.cfRange, &selection))
        let bounds = try #require(unsafe AXValueCreate(.cgRect, &caret))

        #expect(FocusedText.range(range).map { [$0.location, $0.length] } == [4, 0])
        #expect(FocusedText.rect(bounds) == caret)
        #expect(FocusedText.range(bounds) == nil)
        #expect(FocusedText.rect(range) == nil)
        #expect(FocusedText.rect("AXBounds" as CFString) == nil)
    }

    @Test func readsBackOnlyAsFarAsTheStartOfTheText() {
        let middle = FocusedText.readBack(3, from: 10)
        let start = FocusedText.readBack(3, from: 1)

        #expect(middle.location == 7)
        #expect(middle.length == 3)
        #expect(start.location == 0)
        #expect(start.length == 1)
    }

    @Test func ignoresAnEmptyCaret() throws {
        var empty = CGRect.zero
        let bounds = try #require(unsafe AXValueCreate(.cgRect, &empty))

        #expect(FocusedText.rect(bounds) == nil)
    }
}
