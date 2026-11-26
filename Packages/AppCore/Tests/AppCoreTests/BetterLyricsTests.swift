import Foundation
import Testing

@testable import AppCore

@Suite struct BetterLyricsTests {
    private final class Server: @unchecked Sendable {
        var ttml: String?
        var asked: [URL] = []

        func answer(_ url: URL) -> LyricsLookup.Reply {
            asked.append(url)
            guard let ttml else { return .init(data: Data("{}".utf8), status: 404) }
            let body = try? JSONEncoder().encode(["ttml": ttml])
            return .init(data: body ?? Data(), status: 200)
        }
    }

    private static let song = """
        <tt xmlns="http://www.w3.org/ns/ttml" \
        xmlns:itunes="http://music.apple.com/lyric-ttml-internal" \
        xmlns:ttm="http://www.w3.org/ns/ttml#metadata" itunes:timing="Word">\
        <head><metadata><iTunesMetadata xmlns="http://music.apple.com/lyric-ttml-internal">\
        <transliterations><transliteration><text for="L1">\
        <span begin="1.000" end="1.500" xmlns="http://www.w3.org/ns/ttml">a</span>\
        </text></transliteration></transliterations></iTunesMetadata></metadata></head>\
        <body dur="3:21.400"><div begin="1.000" end="1:02.500">\
        <p begin="1.000" end="2.500" itunes:key="L1"><span begin="1.000" end="1.500">あ</span>\
        <span begin="2.000" end="2.500">い</span></p>\
        <p begin="1:00.000" end="1:02.500" itunes:key="L2"><span begin="1:00.000" \
        end="1:00.500">Low</span> <span begin="1:01.000" end="1:02.500">tide</span>\
        <span ttm:role="x-bg"><span begin="1:01.500" end="1:02.000">(tide)</span></span></p>\
        </div></body></tt>
        """

    private let server = Server()
    private let track = MusicPlayer.Track(
        id: "A1B2", title: "Low Tide", artist: "Harbour Lights", isPlaying: true,
        album: "Salt", duration: 201.4)

    @Test func eachLineKeepsItsWordTimesWithoutBackgroundVocals() throws {
        let lyrics = try #require(BetterLyrics.lyrics(fromTTML: Self.song, duration: 201.4))
        #expect(lyrics.source == .betterLyrics && lyrics.isSynced)
        #expect(lyrics.lines.map(\.text) == ["あい", "", "Low tide"])
        #expect(lyrics.lines.map(\.time) == [1, 2.5, 60])
        #expect(
            lyrics.lines[2].words == [
                .init(text: "Low ", time: 60, duration: 0.5),
                .init(text: "tide", time: 61, duration: 1.5),
            ])
    }

    @Test func lyricsForAnotherLengthOrTimedOnlyByLineAreLeftOut() {
        #expect(BetterLyrics.lyrics(fromTTML: Self.song, duration: 230) == nil)
        let lines = Self.song.replacingOccurrences(
            of: "itunes:timing=\"Word\"", with: "itunes:timing=\"Line\"")
        #expect(BetterLyrics.lyrics(fromTTML: lines, duration: 201.4) == nil)
        #expect(BetterLyrics.lyrics(fromTTML: "not xml", duration: 201.4) == nil)
    }

    @Test func aLookupSendsTheTitleArtistAndLengthButNotTheAlbum() async throws {
        server.ttml = Self.song
        let lyrics = await BetterLyrics(load: server.answer).lyrics(for: track)
        #expect(lyrics?.lines.first?.text == "あい")
        let query = URLComponents(
            url: try #require(server.asked.first), resolvingAgainstBaseURL: false)?
            .queryItems?.reduce(into: [String: String]()) { $0[$1.name] = $1.value }
        #expect(query == ["s": "Low Tide", "a": "Harbour Lights", "d": "201"])
    }

    @Test func aSongBetterLyricsDoesNotHaveFallsToTheNextSource() async {
        #expect(await BetterLyrics(load: server.answer).lyrics(for: track) == nil)
        #expect(server.asked.count == 1)
    }
}
