import Foundation
import Testing

@testable import ClipboardKit

@Suite struct SnippetTemplateTests {
    private static let values = SnippetTemplate.Values(
        fields: ["Name": "Hana", "Day": "Thursday"], date: "30 Sep 2026", time: "9:41",
        clipboard: "copied")

    @Test func fillsDateTimeAndClipboard() {
        let template = SnippetTemplate("Sent {date} at {time}: {clipboard}")

        let expansion = template.expand(Self.values)

        #expect(expansion.text == "Sent 30 Sep 2026 at 9:41: copied")
        #expect(expansion.caretBack == 0)
        #expect(template.fields.isEmpty)
    }

    @Test func putsTheCaretAtTheFirstCursorAndDropsTheRest() {
        let template = SnippetTemplate("Thanks, and talk soon!\n{cursor}\n\n— Taro{cursor} 👋🏽")

        let expansion = template.expand(Self.values)

        #expect(expansion.text == "Thanks, and talk soon!\n\n\n— Taro 👋🏽")
        #expect(expansion.caretBack == "\n\n— Taro 👋🏽".count)
    }

    @Test func listsFillInFieldsOnceInTheOrderTheyAppear() {
        let template = SnippetTemplate(
            #"Hi {fill-in name="Name"}, see {fill-in name="Topic"} by "#
                + #"{fill-in name="Day" options="Monday, Thursday,, "}. Bye {fill-in name="Name"}"#)

        #expect(
            template.fields == [
                .init(name: "Name", options: []), .init(name: "Topic", options: []),
                .init(name: "Day", options: ["Monday", "Thursday"]),
            ])
    }

    @Test func marksWhereEachFieldValueLands() {
        let template = SnippetTemplate(#"Hi {fill-in name="Name"}, by {fill-in name="Day"}."#)

        let expansion = template.expand(Self.values)

        #expect(expansion.text == "Hi Hana, by Thursday.")
        #expect(
            expansion.fieldRanges == [
                NSRange(location: 3, length: 4), NSRange(location: 12, length: 8),
            ])
    }

    @Test func namesAnUnnamedFieldFillIn() {
        let template = SnippetTemplate("A {fill-in} and {fill-in   } again")

        #expect(template.fields == [.init(name: "Fill-in", options: [])])
        #expect(template.expand(Self.values).text == "A  and  again")
    }

    @Test func keepsUnknownOrBrokenBracesAsTyped() {
        let text = #"{Date} {date {fill-in name=Name} {fill-in nam} {}"#

        let template = SnippetTemplate(text)

        #expect(template.expand(Self.values).text == text)
        #expect(template.fields.isEmpty)
    }

    @Test func formatsTheDateAndTimeForNow() {
        let now = SnippetTemplate.Values.now(fields: [:], clipboard: "x")

        #expect(!now.date.isEmpty)
        #expect(!now.time.isEmpty)
        #expect(now.clipboard == "x")
    }
}
