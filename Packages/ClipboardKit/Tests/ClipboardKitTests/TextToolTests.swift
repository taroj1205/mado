import Foundation
import Testing

@testable import ClipboardKit

@Suite struct TextToolTests {
    private static let recipes = "banana bread\napple pie\nbanana bread\ncherry tart\n"

    @Test func removesLaterCopiesOfALineButKeepsBlankLines() {
        let text = "banana bread\n\napple pie\nbanana bread\n\ncherry tart\n"

        #expect(
            TextTool.removeDuplicateLines.apply(to: text)
                == .changed("banana bread\n\napple pie\n\ncherry tart\n"))
        #expect(TextTool.duplicateLines(in: text) == [3])
        #expect(TextTool.removeDuplicateLines.apply(to: "one\ntwo") == .unchanged)
    }

    @Test func sortsLinesInFinderOrderAndKeepsTheTrailingNewline() {
        #expect(
            TextTool.sortLines.apply(to: "item 10\nItem 2\napple\n")
                == .changed("apple\nItem 2\nitem 10\n"))
        #expect(TextTool.sortLines.apply(to: "a\nb") == .unchanged)
    }

    @Test func changesCase() {
        #expect(TextTool.titleCase.apply(to: "banana BREAD") == .changed("Banana Bread"))
        #expect(TextTool.uppercase.apply(to: "Straße") == .changed("STRASSE"))
        #expect(TextTool.lowercase.apply(to: "ÉCOLE") == .changed("école"))
        #expect(TextTool.uppercase.apply(to: "DONE 1") == .unchanged)
    }

    @Test func trimsTheWholeSelection() {
        #expect(TextTool.trimWhitespace.apply(to: "\n  hi there \t\n") == .changed("hi there"))
        #expect(TextTool.trimWhitespace.apply(to: "hi") == .unchanged)
    }

    @Test func encodesAndDecodesURLs() {
        #expect(
            TextTool.urlEncode.apply(to: "a b&c=d/é~") == .changed("a%20b%26c%3Dd%2F%C3%A9~"))
        #expect(TextTool.urlDecode.apply(to: "a%20b%26c%3Dd%2F%C3%A9~") == .changed("a b&c=d/é~"))
        #expect(TextTool.urlDecode.apply(to: "plain") == .unchanged)
        #expect(TextTool.urlDecode.apply(to: "100%") == .invalid)
    }

    @Test func encodesAndDecodesBase64() {
        #expect(TextTool.base64Encode.apply(to: "banana bread") == .changed("YmFuYW5hIGJyZWFk"))
        #expect(TextTool.base64Decode.apply(to: "YmFuYW5hIGJyZWFk") == .changed("banana bread"))
        #expect(TextTool.base64Decode.apply(to: "YmFu\nYW5h") == .changed("banana"))
        #expect(TextTool.base64Decode.apply(to: "8J-Ygw") == .changed("😃"))
        #expect(TextTool.base64Decode.apply(to: "not base64!") == .invalid)
        #expect(TextTool.base64Decode.apply(to: "//79") == .invalid)
    }

    @Test func formatsJSONKeepingKeyOrderAndStrings() {
        let json = #"{"b":[1,{"c":"x, {y}: \"z\""}],"a":{},"e":[ ]}"#

        let formatted = [
            "{", #"  "b": ["#, "    1,", "    {", #"      "c": "x, {y}: \"z\"""#, "    }", "  ],",
            #"  "a": {},"#, #"  "e": []"#, "}",
        ]

        #expect(TextTool.formatJSON.apply(to: json) == .changed(formatted.joined(separator: "\n")))
    }

    @Test func formatsOnlyObjectsAndArrays() {
        #expect(TextTool.formatJSON.apply(to: "{\"a\": }") == .invalid)
        #expect(TextTool.formatJSON.apply(to: "42") == .invalid)
        #expect(TextTool.formatJSON.apply(to: "[\n  1\n]") == .unchanged)
    }

    @Test func summarisesWhatEachToolWouldDo() {
        let text = Self.recipes
        let summary = { (tool: TextTool) in tool.summary(of: tool.apply(to: text), from: text) }

        #expect(summary(.removeDuplicateLines) == "4 lines → 3")
        #expect(summary(.sortLines) == "A → Z")
        #expect(summary(.titleCase) == "Banana Bread · Apple Pie · Banana Bread · Cherry Tart")
        #expect(summary(.trimWhitespace) == "banana bread · apple pie · banana bread · cherry tart")
        #expect(summary(.urlDecode) == "Nothing to decode")
        #expect(summary(.formatJSON) == "Not JSON")
    }

    @Test func countsLinesWordsAndCharacters() {
        let counts = TextTool.Counts(of: Self.recipes)

        #expect([counts.lines, counts.words, counts.characters] as [Int] == [4, 8, 48])
    }
}
