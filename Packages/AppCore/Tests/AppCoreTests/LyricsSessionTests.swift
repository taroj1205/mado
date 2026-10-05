import Foundation
import Testing

@testable import AppCore

@MainActor
@Suite struct LyricsSessionTests {
    private final class Server: @unchecked Sendable {
        var status = 200
        var asked = 0

        func answer(_ url: URL) -> (data: Data, status: Int) {
            asked += 1
            let body = """
                {"duration":200,"instrumental":false,"plainLyrics":"A\\nB",
                "syncedLyrics":"[00:10.00] A\\n[00:20.00] B"}
                """
            return (Data((url.path == "/api/search" ? "[\(body)]" : body).utf8), status)
        }
    }

    private let server = Server()
    private let session: LyricsSession
    private let song = MusicPlayer.Track(
        id: "A1", title: "Low Tide", artist: "Harbour Lights", isPlaying: true, album: "Salt",
        duration: 200)

    init() {
        session = LyricsSession(lookup: LyricsLookup { [server] url in server.answer(url) })
    }

    private func settle() async {
        await session.pending?.value
    }

    @Test func aPlayingSongLoadsThenFollowsItsPosition() async throws {
        var changes = 0
        session.onChange = { changes += 1 }
        session.update(song, position: 12, enabled: true, at: 100)
        #expect(session.state == .loading)
        await settle()
        let lyrics = try #require(session.lyrics)
        #expect(lyrics.isSynced)
        #expect(changes == 2)
        #expect(session.moment(at: 100)?.index == 0)
        #expect(session.moment(at: 108)?.index == 1)
        #expect(session.start(ofLine: 1) == 20)
        #expect(session.start(ofLine: 5) == nil)
    }

    @Test func seekingMovesTheClock() async {
        session.update(song, position: 12, enabled: true, at: 100)
        await settle()
        session.moved(to: 25, isPlaying: true, at: 200)
        #expect(session.moment(at: 201)?.index == 1)
    }

    @Test func theSameSongIsLookedUpOnce() async {
        session.update(song, position: 1, enabled: true, at: 100)
        await settle()
        session.update(song, position: 3, enabled: true, at: 102)
        #expect(server.asked == 1)
        #expect(session.pending == nil)
    }

    @Test func turningItOffOrStoppingTheMusicClearsTheLyrics() async {
        session.update(song, position: 1, enabled: true, at: 100)
        await settle()
        session.update(song, position: 1, enabled: false, at: 102)
        #expect(session.state == .off && session.lyrics == nil)
        session.update(nil, position: nil, enabled: true, at: 104)
        #expect(session.state == .idle)
        session.update(song, position: 1, enabled: true, at: 106)
        await settle()
        #expect(session.lyrics != nil)
    }

    @Test func aFailedLookupIsRetriedAfterAMinuteNotBefore() async {
        server.status = 500
        session.update(song, position: 1, enabled: true, at: 100)
        await settle()
        #expect(session.state == .failed)
        session.update(song, position: 3, enabled: true, at: 130)
        #expect(session.state == .failed && server.asked == 1)
        server.status = 200
        session.update(song, position: 63, enabled: true, at: 161)
        #expect(session.state == .loading)
        await settle()
        #expect(session.lyrics != nil)
    }

    @Test func aNewSongReplacesTheOldLookup() async {
        session.update(song, position: 1, enabled: true, at: 100)
        let next = MusicPlayer.Track(
            id: "B2", title: "Night Drive", artist: "Neon", isPlaying: true)
        session.update(next, position: 0, enabled: true, at: 101)
        await settle()
        #expect(server.asked <= 2)
        #expect(session.lyrics != nil)
    }
}
