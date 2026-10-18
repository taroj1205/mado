import Foundation
import Testing

@testable import SpeechKit

@Suite struct SpeechWordsTests {
    private func decoded(_ json: String) throws -> SpeechWords {
        try JSONDecoder().decode(SpeechWords.self, from: Data(json.utf8))
    }

    @Test func startsEmpty() {
        #expect(SpeechWords().list.isEmpty)
        #expect(SpeechWords().text.isEmpty)
    }

    @Test func wordsAreSplitOnCommasAndLinesInEitherScript() {
        let words = SpeechWords(text: "Mado, Kanary、SwiftUI，Claude Code\nPonytail")
        #expect(words.list == ["Mado", "Kanary", "SwiftUI", "Claude Code", "Ponytail"])
    }

    @Test func blanksAndRepeatsAreDropped() {
        let words = SpeechWords(text: " Mado ,, ,\n Mado, Kanary ,")
        #expect(words.list == ["Mado", "Kanary"])
        #expect(words.text == "Mado, Kanary")
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

    @Test func nothingIsSentWhenEvenTheFirstWordIsTooLong() {
        #expect(SpeechWords(text: "Mado").prompt(fitting: 4) { $0.count } == nil)
    }
}
