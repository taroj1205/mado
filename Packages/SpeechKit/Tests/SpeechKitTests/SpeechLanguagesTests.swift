import Foundation
import Testing

@testable import SpeechKit

@Suite struct SpeechLanguagesTests {
    private func decoded(_ json: String) throws -> SpeechLanguages {
        try JSONDecoder().decode(SpeechLanguages.self, from: Data(json.utf8))
    }

    @Test func startsWithEnglishAndJapanese() {
        #expect(SpeechLanguages().codes == ["en", "ja"])
    }

    @Test func addingKeepsOrderAndIgnoresRepeatsAndUnknownCodes() {
        var languages = SpeechLanguages()
        languages.add("ko")
        languages.add("ko")
        languages.add("xx")
        #expect(languages.codes == ["en", "ja", "ko"])
    }

    @Test func theLastLanguageStays() {
        var languages = SpeechLanguages()
        languages.remove("en")
        languages.remove("ja")
        #expect(languages.codes == ["ja"])
    }

    @Test func savedChoicesSurviveSavingAndLoading() throws {
        var languages = SpeechLanguages()
        languages.add("fr")
        languages.remove("en")
        let loaded = try JSONDecoder().decode(
            SpeechLanguages.self, from: JSONEncoder().encode(languages))
        #expect(loaded == languages)
    }

    @Test func unknownRepeatedOrMissingChoicesAreCleanedUpOnLoad() throws {
        #expect(try decoded(#"["ja","xx","ja","en"]"#).codes == ["ja", "en"])
        #expect(try decoded("[]").codes == ["en", "ja"])
        #expect(try decoded(#"["xx"]"#).codes == ["en", "ja"])
    }

    @Test func cantoneseNeedsALargeV3Vocabulary() {
        let chosen = ["en", "yue", "ja"]
        #expect(SpeechLanguages.usable(chosen, vocabulary: 51_865) == ["en", "ja"])
        #expect(SpeechLanguages.usable(chosen, vocabulary: 51_866) == chosen)
        #expect(SpeechLanguages.usable(["yue"], vocabulary: 51_865).isEmpty)
    }

    @Test func everyChoiceIsAWhisperLanguage() {
        #expect(SpeechLanguages.supported.count > 90)
        #expect(Set(["en", "ja", "ko", "zh"]).isSubset(of: SpeechLanguages.supported))
    }
}
