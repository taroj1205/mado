import Testing

@testable import AppCore

@Suite struct LyricsPaceTests {
    @Test func japaneseIsCountedByMoraeEvenWhenWrittenInKanji() {
        #expect(LyricsPace.morae(in: "沈むように溶けてゆくように") == 14)
        #expect(LyricsPace.morae(in: "今日") == 2)
        #expect(LyricsPace.morae(in: "フェンス越しに") == 6)
        #expect(LyricsPace.morae(in: "さよなら") == 4)
    }

    @Test func latinWordsAreCountedBySyllableAndPunctuationIsSilent() {
        #expect(LyricsPace.morae(in: "Hello world") == 3)
        #expect(LyricsPace.morae(in: "「…」") == 0)
        #expect(LyricsPace.morae(in: "") == 0)
    }

    private func song(lastGap: Double) throws -> Lyrics {
        let starts = (0...9).map { $0 * 2 } + [18 + Int(lastGap)]
        let rows = starts.map { "[00:\($0 < 10 ? "0" : "")\($0).00] ああああ" }
        return try #require(Lyrics(synced: rows.joined(separator: "\n"), plain: nil))
    }

    @Test func aLineStopsFillingOnceItsSungLengthIsUp() throws {
        let lyrics = try song(lastGap: 20)
        #expect(lyrics.moment(at: 20, duration: 100)?.progress == 0.5)
        #expect(lyrics.moment(at: 22, duration: 100)?.progress == 1)
        #expect(lyrics.moment(at: 30, duration: 100)?.remaining == 0)
    }

    @Test func aLineKeepsItsWholeGapWhenTheSongPaceIsSlowEnough() throws {
        let lyrics = try song(lastGap: 4)
        #expect(lyrics.moment(at: 20, duration: 100)?.progress == 0.5)
        #expect(lyrics.moment(at: 22, duration: 100)?.progress == 0)
    }

    @Test func shortSongsAreNotTrimmedBecauseTheirPaceIsGuesswork() throws {
        let lyrics = try #require(
            Lyrics(synced: "[00:00.00] ああああ\n[00:20.00] ああ", plain: nil))
        #expect(lyrics.moment(at: 10, duration: 100)?.progress == 0.5)
    }

    @Test func aSongWithOneEnglishLineFillsItFromStartToEnd() throws {
        let lyrics = try #require(Lyrics(synced: "[00:10.00] Hello world", plain: nil))
        #expect(lyrics.moment(at: 10, duration: 100)?.progress == 0)
        let half = try #require(lyrics.moment(at: 55, duration: 100)?.progress)
        #expect(half > 0 && half < 1)
        let end = try #require(lyrics.moment(at: 100, duration: 100))
        #expect(end.progress == 1)
        #expect(end.remaining == 0)
    }

    @Test func plainKanaAdvanceAtTheSameSpeedAsTheirWidth() {
        let curve = LyricsPaceCurve("あいうえおかきく")
        #expect(abs(curve.reach(at: 0.5) - 0.5) < 1e-9)
        #expect(curve.reach(at: 1) == 1)
    }

    @Test func aKanjiWithALongReadingTakesLongerThanItsWidth() {
        let curve = LyricsPaceCurve("沈む")
        #expect(abs(curve.reach(at: 1.0 / 3) - 0.25) < 1e-9)
        #expect(abs(curve.reach(at: 2.0 / 3) - 0.5) < 1e-9)
    }

    @Test func punctuationIsPassedWithoutTakingTime() {
        let curve = LyricsPaceCurve("あ、い")
        #expect(abs(curve.reach(at: 0.5) - 2.0 / 3) < 1e-9)
    }

    @Test func aMomentListsWhereTheLineWillBeAtEachLaterCharacter() throws {
        let lyrics = try song(lastGap: 4)
        let moment = try #require(lyrics.moment(at: 20, duration: 100))
        #expect(moment.ahead.map(\.seconds) == [1, 2])
        #expect(moment.ahead.last == Lyrics.Step(seconds: 2, reach: 1))
    }
}
