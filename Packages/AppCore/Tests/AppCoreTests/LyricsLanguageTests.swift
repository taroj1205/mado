import Testing

@testable import AppCore

@Suite struct LyricsLanguageTests {
    private func lyrics(_ text: String) -> Lyrics {
        Lyrics(lines: [.init(time: nil, text: text)], isSynced: false)
    }

    @Test func japaneseNeedsKana() {
        #expect(LyricsLanguage(detecting: lyrics("夜に駆ける")) == .japanese)
        #expect(LyricsLanguage(detecting: lyrics("ヨルシカ")) == .japanese)
        #expect(LyricsLanguage(detecting: lyrics("夜")) == nil)
    }

    @Test func koreanNeedsHangul() {
        #expect(LyricsLanguage(detecting: lyrics("안녕하세요")) == .korean)
    }

    @Test func romanizedAndEnglishLyricsHaveNoOriginalLanguage() {
        #expect(LyricsLanguage(detecting: lyrics("Yoru ni kakeru")) == nil)
        #expect(LyricsLanguage(detecting: lyrics("")) == nil)
    }

    @Test func aFewJapaneseWordsInAnEnglishSongDoNotCount() {
        let song = "Oh baby hold me close tonight I need you here with me stay till the light ありがとう"
        #expect(LyricsLanguage(detecting: lyrics(song)) == nil)
    }

    @Test func theScriptWithTheLargerShareWins() {
        let korean = "안녕하세요 안녕하세요 안녕하세요 こんにちは"
        let japanese = "こんにちは こんにちは こんにちは 안녕하세요"
        #expect(LyricsLanguage(detecting: lyrics(korean)) == .korean)
        #expect(LyricsLanguage(detecting: lyrics(japanese)) == .japanese)
    }

    @Test func theMostCommonLanguageWinsAndTiesGoToJapanese() {
        #expect(LyricsLanguage.prevailing(in: [.korean, .japanese, .korean]) == .korean)
        #expect(LyricsLanguage.prevailing(in: [.korean, .japanese]) == .japanese)
        #expect(LyricsLanguage.prevailing(in: []) == nil)
    }
}
