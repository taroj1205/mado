import Foundation
import Testing

@testable import SpeechKit

@Suite struct SpeechWordsTests {
    private func decoded(_ json: String) throws -> SpeechWords {
        try JSONDecoder().decode(SpeechWords.self, from: Data(json.utf8))
    }

    @Test func startsEmpty() {
        #expect(SpeechWords().list.isEmpty)
    }

    @Test func wordsAreSplitOnCommasAndLinesInEitherScript() {
        let words = SpeechWords(text: "Mado, Kanary、SwiftUI，Claude Code\nPonytail")
        #expect(words.list == ["Mado", "Kanary", "SwiftUI", "Claude Code", "Ponytail"])
    }

    @Test func blanksAndRepeatsAreDropped() {
        let words = SpeechWords(text: " Mado ,, ,\n Mado, Kanary ,")
        #expect(words.list == ["Mado", "Kanary"])
    }

    @Test func addedWordsGoLastAndRepeatsAreIgnored() {
        var words = SpeechWords(text: "Mado")
        words.add("Kanary, 窓")
        words.add(" Mado ")
        words.add("   ")
        #expect(words.list == ["Mado", "Kanary", "窓"])
    }

    @Test func removingAWordKeepsTheOrderOfTheRest() {
        var words = SpeechWords(text: "Mado, Kanary, SwiftUI")
        words.remove("Kanary")
        words.remove("Missing")
        #expect(words.list == ["Mado", "SwiftUI"])
    }

    @Test func aWordMovesUpAndDownButNotPastTheEnds() {
        var words = SpeechWords(text: "Mado, Kanary, SwiftUI")
        words.move("SwiftUI", by: -1)
        #expect(words.list == ["Mado", "SwiftUI", "Kanary"])
        words.move("Mado", by: -1)
        words.move("Kanary", by: 1)
        words.move("Missing", by: -1)
        #expect(words.list == ["Mado", "SwiftUI", "Kanary"])
        words.move("Mado", by: 1)
        #expect(words.list == ["SwiftUI", "Mado", "Kanary"])
    }

    @Test func savedWordsSurviveSavingAndLoading() throws {
        let saved = SpeechWords(text: "Mado, 窓")
        let data = try JSONEncoder().encode(saved)
        #expect(String(bytes: data, encoding: .utf8) == #"["Mado","窓"]"#)
        #expect(try JSONDecoder().decode(SpeechWords.self, from: data) == saved)
    }

    @Test func savedWordsAreCleanedOnLoading() throws {
        #expect(try decoded(#"["Mado", " ", "Mado", "a, b"]"#).list == ["Mado", "a", "b"])
    }

    @Test func thePromptIsOneSentenceEndingInAPeriod() {
        let prompt = SpeechWords(text: "Mado, Kanary").prompt(fitting: 100) { $0.count }
        #expect(prompt == "Mado, Kanary.")
    }

    @Test func noWordsMeansNoPrompt() {
        #expect(SpeechWords().prompt(fitting: 100) { $0.count } == nil)
    }

    @Test func aLongListKeepsTheWordsWrittenFirst() {
        let words = SpeechWords(text: "Mado, Kanary, SwiftUI")
        #expect(words.prompt(fitting: 14) { $0.count } == "Mado, Kanary.")
        #expect(words.prompt(fitting: 5) { $0.count } == "Mado.")
    }

    @Test func aHugeListIsTrimmedWithAFewTokenCounts() throws {
        let words = SpeechWords(text: (0..<5_000).map { "word\($0)" }.joined(separator: ", "))
        var calls = 0
        let prompt = words.prompt(fitting: 100) { text in
            calls += 1
            return text.count
        }
        #expect(try #require(prompt).count <= 100)
        #expect(prompt?.hasPrefix("word0, word1, word2") == true)
        #expect(calls <= 20)
    }

    @Test func nothingIsSentWhenEvenTheFirstWordIsTooLong() {
        #expect(SpeechWords(text: "Mado").prompt(fitting: 4) { $0.count } == nil)
    }
}
