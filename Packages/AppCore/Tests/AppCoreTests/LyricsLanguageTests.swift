import Testing

@testable import AppCore

@Suite struct LyricsLanguageTests {
    private func lyrics(_ text: String) -> Lyrics {
        Lyrics(lines: [.init(time: nil, text: text)], isSynced: false)
    }

    @Test func automaticAcceptsAnything() {
        #expect(LyricsLanguage.any.accepts(lyrics("Hello")))
        #expect(LyricsLanguage.any.accepts(lyrics("")))
    }

    @Test func japaneseNeedsKana() {
        #expect(LyricsLanguage.japanese.accepts(lyrics("夜に駆ける")))
        #expect(LyricsLanguage.japanese.accepts(lyrics("ヨルシカ")))
        #expect(!LyricsLanguage.japanese.accepts(lyrics("Yoru ni kakeru")))
        #expect(!LyricsLanguage.japanese.accepts(lyrics("夜")))
        #expect(!LyricsLanguage.japanese.accepts(lyrics("")))
    }

    @Test func aFewJapaneseWordsInAnEnglishSongDoNotCount() {
        let song = "Oh baby hold me close tonight I need you here with me stay till the light ありがとう"
        #expect(!LyricsLanguage.japanese.accepts(lyrics(song)))
    }

    @Test func koreanNeedsHangul() {
        #expect(LyricsLanguage.korean.accepts(lyrics("안녕하세요")))
        #expect(!LyricsLanguage.korean.accepts(lyrics("こんにちは")))
    }
}
