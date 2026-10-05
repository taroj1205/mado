import Testing

@testable import AppCore

@Suite struct LyricsTests {
    private let synced = """
        [ar:Harbour Lights]
        [00:12.50] Salt on the window
        [00:20.00]
        [00:25.25][01:05.00] Low tide, low tide
        [00:03.00] First light
        """

    @Test func syncedLinesAreSortedAndMetadataIsDropped() throws {
        let lyrics = try #require(Lyrics(synced: synced, plain: nil))
        #expect(lyrics.isSynced)
        #expect(
            lyrics.lines.map(\.text) == [
                "First light", "Salt on the window", "", "Low tide, low tide",
                "Low tide, low tide",
            ])
        #expect(lyrics.lines.map(\.time) == [3, 12.5, 20, 25.25, 65])
    }

    @Test func theCurrentLineIsTheLastOneAtOrBeforeThePosition() throws {
        let lyrics = try #require(Lyrics(synced: synced, plain: nil))
        #expect(lyrics.index(at: 2.9) == nil)
        #expect(lyrics.index(at: 3) == 0)
        #expect(lyrics.index(at: 20) == 2)
        #expect(lyrics.index(at: 64.9) == 3)
        #expect(lyrics.index(at: 500) == 4)
    }

    @Test func theMomentFillsTheLineUntilTheNextOneStarts() throws {
        let lyrics = try #require(Lyrics(synced: synced, plain: nil))
        #expect(lyrics.moment(at: 2, duration: 100) == nil)
        let first = Lyrics.Moment(index: 0, progress: 0.5, remaining: 4.75)
        #expect(lyrics.moment(at: 7.75, duration: 100) == first)
        #expect(lyrics.moment(at: 12.5, duration: 100)?.progress == 0)
        #expect(lyrics.moment(at: 25.25, duration: 100)?.index == 3)
        #expect(lyrics.moment(at: 25.25, duration: 100)?.remaining == 39.75)
    }

    @Test func theLastLineRunsToTheTrackEndOrAShortDefault() throws {
        let lyrics = try #require(Lyrics(synced: synced, plain: nil))
        #expect(lyrics.moment(at: 75, duration: 95)?.remaining == 20)
        #expect(lyrics.moment(at: 70, duration: nil)?.remaining == 0)
        #expect(lyrics.moment(at: 400, duration: 95)?.progress == 1)
    }

    @Test func plainLyricsKeepVerseBreaksButTrimTheEnds() throws {
        let lyrics = try #require(Lyrics(synced: nil, plain: "\n\nOne\nTwo\n\nThree\n\n"))
        #expect(!lyrics.isSynced)
        #expect(lyrics.lines.map(\.text) == ["One", "Two", "", "Three"])
        #expect(lyrics.index(at: 10) == nil)
    }

    @Test func syncedWinsOverPlainAndEmptyInputGivesNothing() {
        #expect(Lyrics(synced: "[00:01.00] A", plain: "B")?.lines.first?.text == "A")
        #expect(Lyrics(synced: "[ar:x]", plain: "B")?.isSynced == false)
        #expect(Lyrics(synced: "", plain: " \n ") == nil)
        #expect(Lyrics(synced: nil, plain: nil) == nil)
    }

    @Test func malformedTimestampsAreIgnored() throws {
        let text = "[x:12] no\n[-1:00] no\n[1:xx] no\n[1:02] yes"
        let lyrics = try #require(Lyrics(synced: text, plain: nil))
        #expect(lyrics.lines == [.init(time: 62, text: "yes")])
    }

    @Test func theClockRunsOnlyWhilePlaying() {
        var clock = LyricsClock()
        clock.sync(position: 10, at: 100, isPlaying: true)
        #expect(clock.position(at: 102.5) == 12.5)
        #expect(clock.position(at: 99) == 10)
        clock.sync(position: 20, at: 200, isPlaying: false)
        #expect(clock.position(at: 230) == 20)
    }
}
