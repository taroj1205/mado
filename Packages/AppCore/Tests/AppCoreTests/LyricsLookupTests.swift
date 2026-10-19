import Foundation
import Testing

@testable import AppCore

@Suite struct LyricsLookupTests {
    private final class Server: @unchecked Sendable {
        var replies: [String: (Int, String)] = [:]
        var titleOnly: (Int, String)?
        var busy: [String: Int] = [:]
        var asked: [URL] = []

        func answer(_ url: URL) -> (data: Data, status: Int) {
            asked.append(url)
            if let left = busy[url.path], left > 0 {
                busy[url.path] = left - 1
                return (Data(), 503)
            }
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            let named = items?.contains { $0.name == "artist_name" } ?? false
            let reply = (named ? nil : titleOnly) ?? replies[url.path] ?? (404, "{}")
            return (Data(reply.1.utf8), reply.0)
        }
    }

    private static let greeting = Lyrics(lines: [.init(time: 1, text: "Hi")], isSynced: true)

    private let server = Server()
    private let lookup: LyricsLookup
    private let track = MusicPlayer.Track(
        id: "A1B2", title: "Low Tide", artist: "Harbour Lights", isPlaying: true,
        album: "Salt", duration: 201.4)

    init() {
        lookup = LyricsLookup { [server] url in server.answer(url) }
    }

    private func entry(
        duration: Double = 201, synced: String? = "[00:01.00] Hi", plain: String? = "Hi",
        instrumental: Bool = false
    ) -> String {
        let sync = synced.map { "\"\($0)\"" } ?? "null"
        let rows = plain.map { "\"\($0)\"" } ?? "null"
        return """
            {"duration":\(duration),"instrumental":\(instrumental),
            "plainLyrics":\(rows),"syncedLyrics":\(sync)}
            """
    }

    @Test func anExactMatchSendsTheTrackDetails() async throws {
        server.replies["/api/get"] = (200, entry())
        #expect(
            try await lookup.lyrics(for: track)
                == .found(Self.greeting))
        let query = URLComponents(url: server.asked[0], resolvingAgainstBaseURL: false)?
            .queryItems?.reduce(into: [String: String]()) { $0[$1.name] = $1.value }
        #expect(
            query == [
                "track_name": "Low Tide", "artist_name": "Harbour Lights", "album_name": "Salt",
                "duration": "201",
            ])
    }

    @Test func aMissingExactMatchFallsBackToTheClosestSearchResult() async throws {
        server.replies["/api/search"] = (
            200, "[\(entry(duration: 260, synced: nil, plain: "Far")),\(entry(duration: 203))]"
        )
        #expect(
            try await lookup.lyrics(for: track)
                == .found(Self.greeting))
    }

    @Test func withoutAnAlbumOrLengthItSearchesAndPrefersSyncedLyrics() async throws {
        server.replies["/api/search"] = (
            200, "[\(entry(synced: nil, plain: "Plain")),\(entry(duration: 202))]"
        )
        let bare = MusicPlayer.Track(id: "B", title: "Low Tide", artist: "Harbour", isPlaying: true)
        #expect(try await lookup.lyrics(for: bare) == .found(Self.greeting))
        #expect(server.asked.map(\.path) == ["/api/search"])
    }

    @Test func ofSeveralSyncedMatchesTheClosestLengthWins() async throws {
        server.replies["/api/search"] = (
            200,
            "[\(entry(duration: 203, synced: "[00:09.00] Late")),\(entry(duration: 201))]"
        )
        #expect(try await lookup.lyrics(for: track) == .found(Self.greeting))
    }

    @Test func anExactMatchWithoutWordsStillTriesTheSearch() async throws {
        server.replies["/api/get"] = (200, entry(synced: nil, plain: nil))
        server.replies["/api/search"] = (200, "[\(entry(duration: 202))]")
        #expect(try await lookup.lyrics(for: track) == .found(Self.greeting))
    }

    @Test func aNearEntryWithoutWordsDoesNotHideALaterOneWithWords() async throws {
        server.replies["/api/search"] = (
            200, "[\(entry(synced: nil, plain: nil)),\(entry(duration: 202))]"
        )
        #expect(try await lookup.lyrics(for: track) == .found(Self.greeting))
    }

    @Test func otherLengthsStillShowTheirWordsUnsynced() async throws {
        server.replies["/api/search"] = (
            200, "[\(entry(duration: 260, synced: nil, plain: nil)),\(entry(duration: 260))]"
        )
        let words = Lyrics(lines: [.init(time: nil, text: "Hi")], isSynced: false)
        #expect(try await lookup.lyrics(for: track) == .found(words))
    }

    @Test func aDifferentlySpeltArtistIsFoundByTitleAndLength() async throws {
        server.replies["/api/search"] = (200, "[\(entry(duration: 260))]")
        server.titleOnly = (200, "[\(entry(duration: 202))]")
        #expect(try await lookup.lyrics(for: track) == .found(Self.greeting))
    }

    @Test func aTitleAloneNeedsAnAlmostIdenticalLength() async throws {
        server.titleOnly = (200, "[\(entry(duration: 203))]")
        #expect(try await lookup.lyrics(for: track) == .missing)
    }

    @Test func aTitleAloneNeverMakesATrackInstrumental() async throws {
        server.titleOnly = (
            200, "[\(entry(synced: nil, plain: nil, instrumental: true))]"
        )
        #expect(try await lookup.lyrics(for: track) == .missing)
    }

    @Test func aBusyServerIsAskedAgain() async throws {
        server.busy["/api/get"] = 2
        server.replies["/api/get"] = (200, entry())
        #expect(try await lookup.lyrics(for: track) == .found(Self.greeting))
        #expect(server.asked.count == 3)
    }

    @Test func aServerThatStaysBusyEndsInAFailure() async throws {
        server.busy["/api/get"] = 10
        await #expect(throws: LyricsLookup.Failure.badResponse) {
            _ = try await lookup.lyrics(for: track)
        }
        #expect(server.asked.count == 3)
    }

    @Test func instrumentalAndUnknownTracksAreReportedAsSuch() async throws {
        server.replies["/api/get"] = (200, entry(synced: nil, plain: nil, instrumental: true))
        #expect(try await lookup.lyrics(for: track) == .instrumental)
        server.replies["/api/get"] = nil
        let other = MusicPlayer.Track(id: "Z", title: "Nope", artist: "Nobody", isPlaying: true)
        #expect(try await lookup.lyrics(for: other) == .missing)
    }

    @Test func answersAreRememberedButFailuresAreNot() async throws {
        server.replies["/api/get"] = (500, "")
        await #expect(throws: LyricsLookup.Failure.badResponse) {
            _ = try await lookup.lyrics(for: track)
        }
        server.replies["/api/get"] = (200, entry())
        _ = try await lookup.lyrics(for: track)
        let calls = server.asked.count
        _ = try await lookup.lyrics(for: track)
        #expect(server.asked.count == calls)
    }
}
