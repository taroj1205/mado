import Foundation
import Testing

@testable import AppCore

@Suite struct LyricsLookupTests {
    private final class Server: @unchecked Sendable {
        var replies: [String: (Int, String)] = [:]
        var titleOnly: (Int, String)?
        var sameAlbum: (Int, String)?
        var busy: [String: Int] = [:]
        var retryAfter: TimeInterval?
        var asked: [URL] = []

        func answer(_ url: URL) -> LyricsLookup.Reply {
            asked.append(url)
            if let left = busy[url.path], left > 0 {
                busy[url.path] = left - 1
                return .init(data: Data(), status: 503, retryAfter: retryAfter)
            }
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            let named = items?.contains { $0.name == "artist_name" } ?? false
            let album = items?.contains { $0.name == "album_name" } ?? false
            let known = replies[url.path] ?? (404, "{}")
            let reply =
                if named {
                    known
                } else if album {
                    sameAlbum ?? (404, "{}")
                } else {
                    titleOnly ?? known
                }
            return .init(data: Data(reply.1.utf8), status: reply.0, retryAfter: retryAfter)
        }
    }

    private static let greeting = Lyrics(lines: [.init(time: 1, text: "Hi")], isSynced: true)
    private static let japanese = Lyrics(
        lines: [.init(time: 1, text: "こんにちは")], isSynced: true)
    private static let korean = Lyrics(
        lines: [.init(time: 1, text: "안녕하세요")], isSynced: true)

    private let server = Server()
    private let lookup: LyricsLookup
    private let track = MusicPlayer.Track(
        id: "A1B2", title: "Low Tide", artist: "Harbour Lights", isPlaying: true,
        album: "Salt", duration: 201.4)

    init() {
        lookup = LyricsLookup { [server] url in server.answer(url) }
    }

    private func entry(
        title: String? = nil, duration: Double = 201, synced: String? = "[00:01.00] Hi",
        plain: String? = "Hi", instrumental: Bool = false
    ) -> String {
        let name = title.map { "\"trackName\":\"\($0)\"," } ?? ""
        let sync = synced.map { "\"\($0)\"" } ?? "null"
        let rows = plain.map { "\"\($0)\"" } ?? "null"
        return """
            {\(name)"duration":\(duration),"instrumental":\(instrumental),
            "plainLyrics":\(rows),"syncedLyrics":\(sync)}
            """
    }

    private func written(_ words: String, duration: Double = 201) -> String {
        entry(duration: duration, synced: "[00:01.00] \(words)", plain: words)
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
        server.titleOnly = (200, "[\(entry(title: "LOW TIDE", duration: 202))]")
        #expect(try await lookup.lyrics(for: track) == .found(Self.greeting))
    }

    @Test func aTitleAloneNeedsAnAlmostIdenticalLength() async throws {
        server.titleOnly = (200, "[\(entry(title: "Low Tide", duration: 203))]")
        #expect(try await lookup.lyrics(for: track) == .missing)
    }

    @Test func aTitleAloneNeedsTheSameTitle() async throws {
        let live = entry(title: "Low Tide (Live)", duration: 202)
        server.titleOnly = (200, "[\(live),\(entry(duration: 202))]")
        #expect(try await lookup.lyrics(for: track) == .missing)
    }

    @Test func aTitleAloneNeverMakesATrackInstrumental() async throws {
        server.titleOnly = (
            200, "[\(entry(title: "Low Tide", synced: nil, plain: nil, instrumental: true))]"
        )
        #expect(try await lookup.lyrics(for: track) == .missing)
    }

    @Test func aFailedTitleSearchKeepsTheWordsFromTheArtistSearch() async throws {
        server.replies["/api/search"] = (200, "[\(entry(duration: 260, synced: nil))]")
        server.titleOnly = (503, "")
        let words = Lyrics(lines: [.init(time: nil, text: "Hi")], isSynced: false)
        #expect(try await lookup.lyrics(for: track) == .found(words))
    }

    @Test func aFailedTitleSearchWithNothingElseIsAFailureNotAMiss() async throws {
        server.titleOnly = (503, "")
        await #expect(throws: LyricsLookup.Failure.badResponse) {
            _ = try await lookup.lyrics(for: track)
        }
    }

    @Test func aBusyServerIsAskedAgain() async throws {
        server.busy["/api/get"] = 2
        server.replies["/api/get"] = (200, entry())
        #expect(try await lookup.lyrics(for: track) == .found(Self.greeting))
        #expect(server.asked.filter { $0.path == "/api/get" }.count == 3)
    }

    @Test func aRetryAfterIsWaitedOutBeforeAskingAgain() async throws {
        server.busy["/api/get"] = 1
        server.retryAfter = 0.2
        server.replies["/api/get"] = (200, entry())
        let start = ContinuousClock.now
        #expect(try await lookup.lyrics(for: track) == .found(Self.greeting))
        #expect(ContinuousClock.now - start >= .milliseconds(200))
    }

    @Test func aRetryAfterThatIsTooLongIsNotWaitedFor() async throws {
        server.busy["/api/get"] = 10
        server.retryAfter = 3_600
        await #expect(throws: LyricsLookup.Failure.badResponse) {
            _ = try await lookup.lyrics(for: track)
        }
        #expect(server.asked.count == 1)
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

    @Test func anExactMatchInTheOriginalLanguageNeedsNoMoreSearching() async throws {
        server.replies["/api/get"] = (200, written("こんにちは"))
        #expect(try await lookup.lyrics(for: track) == .found(Self.japanese))
        #expect(server.asked.map(\.path) == ["/api/get"])
    }

    @Test func aRomanizedExactMatchGivesWayToTheOriginalLyricsOnTheSameAlbum() async throws {
        server.replies["/api/get"] = (200, entry())
        server.sameAlbum = (200, "[\(entry()),\(written("こんにちは", duration: 203))]")
        #expect(try await lookup.lyrics(for: track) == .found(Self.japanese))
    }

    @Test func theOriginalLanguageBeatsACloserRomanizedEntryInTheSearch() async throws {
        let farther = written("こんにちは", duration: 203)
        server.replies["/api/search"] = (200, "[\(entry(duration: 201)),\(farther)]")
        #expect(try await lookup.lyrics(for: track) == .found(Self.japanese))
    }

    @Test func whenTheOriginalsDifferTheMostCommonOneWins() async throws {
        server.replies["/api/get"] = (200, entry())
        let hangul = written("안녕하세요")
        let again = written("안녕하세요", duration: 202)
        server.sameAlbum = (200, "[\(hangul),\(again),\(written("こんにちは"))]")
        #expect(try await lookup.lyrics(for: track) == .found(Self.korean))
    }

    @Test func aSongWithoutAnOriginalLanguageKeepsTheExactMatch() async throws {
        server.replies["/api/get"] = (200, entry())
        server.sameAlbum = (200, "[\(entry(duration: 202, synced: nil))]")
        #expect(try await lookup.lyrics(for: track) == .found(Self.greeting))
        #expect(server.asked.map(\.path) == ["/api/get", "/api/search"])
    }

    @Test func aFailedAlbumSearchKeepsTheExactLyrics() async throws {
        server.replies["/api/get"] = (200, entry())
        server.sameAlbum = (503, "")
        #expect(try await lookup.lyrics(for: track) == .found(Self.greeting))
    }

    @Test func anInstrumentalAlbumEntryDoesNotReplaceTheExactLyrics() async throws {
        server.replies["/api/get"] = (200, entry())
        server.sameAlbum = (
            200, "[\(entry(duration: 201, synced: nil, plain: nil, instrumental: true))]"
        )
        #expect(try await lookup.lyrics(for: track) == .found(Self.greeting))
    }

    @Test func anAlbumEntryInLatinTextDoesNotSkipTheArtistSearch() async throws {
        server.sameAlbum = (200, "[\(written("Wrong"))]")
        server.replies["/api/search"] = (200, "[\(entry(duration: 202))]")
        #expect(try await lookup.lyrics(for: track) == .found(Self.greeting))
    }

    @Test func anInstrumentalAlbumEntryDoesNotSkipTheArtistSearch() async throws {
        server.sameAlbum = (
            200, "[\(entry(duration: 201, synced: nil, plain: nil, instrumental: true))]"
        )
        server.replies["/api/search"] = (200, "[\(entry(duration: 202))]")
        #expect(try await lookup.lyrics(for: track) == .found(Self.greeting))
    }

    @Test func aCloserAlbumEntryInLatinTextDoesNotReplaceTheExactMatch() async throws {
        server.replies["/api/get"] = (200, entry(duration: 202))
        server.sameAlbum = (200, "[\(written("Other", duration: 201.4))]")
        #expect(try await lookup.lyrics(for: track) == .found(Self.greeting))
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
