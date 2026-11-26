import Compression
import Foundation
import Testing

@testable import AppCore

@Suite struct KuGouLyricsTests {
    private final class Server: @unchecked Sendable {
        var candidates = "[]"
        var files: [String: String] = [:]
        var asked: [URL] = []
        private let lock = NSLock()

        func answer(_ url: URL) -> LyricsLookup.Reply {
            lock.lock()
            defer { lock.unlock() }
            asked.append(url)
            let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                .first { $0.name == "id" }?.value
            let body =
                url.path == "/search"
                ? "{\"candidates\":\(candidates)}"
                : id.flatMap { files[$0] }.map { "{\"content\":\"\($0)\"}" }
            return .init(data: Data((body ?? "{}").utf8), status: body == nil ? 404 : 200)
        }
    }

    private static let key: [UInt8] = [
        0x40, 0x47, 0x61, 0x77, 0x5E, 0x32, 0x74, 0x47, 0x51, 0x36, 0x31, 0x2D, 0xCE, 0xD2, 0x6E,
        0x69,
    ]
    private static let song = """
        [ti:Low Tide]
        [offset:0]
        [0,900]<0,300,0>Low Tide - <300,300,0>Harbour Lights
        [900,100]<0,50,0>词：<50,50,0>Someone
        [1000,1500]<0,500,0>あ<1000,500,0>い
        [10000,1000]<0,500,0>う<500,500,0>え
        """

    private let server = Server()
    private let track = MusicPlayer.Track(
        id: "A1B2", title: "Low Tide", artist: "Harbour Lights", isPlaying: true,
        album: "Salt", duration: 201.4)

    private static func encoded(_ krc: String) throws -> String {
        var deflated = Data()
        let filter = try OutputFilter(.compress, using: .zlib) { deflated.append($0 ?? Data()) }
        try filter.write(Data(krc.utf8))
        try filter.finalize()
        let zlib = Data([0x78, 0x9C]) + deflated + Data([0, 0, 0, 0])
        let scrambled = zlib.enumerated().map { $1 ^ key[$0 % key.count] }
        return (Data("krc1".utf8) + Data(scrambled)).base64EncodedString()
    }

    private func candidate(
        _ id: String, song: String = "Low Tide", singer: String = "Harbour Lights",
        length: Int = 201_000
    ) -> String {
        "{\"id\":\"\(id)\",\"accesskey\":\"K\(id)\",\"song\":\"\(song)\","
            + "\"singer\":\"\(singer)\",\"duration\":\(length)}"
    }

    private func downloaded() -> [String] {
        server.asked.compactMap { url in
            URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                .first { $0.name == "id" }?.value
        }
    }

    @Test func aKRCFileIsUnscrambledAndInflated() throws {
        #expect(KuGouLyrics.decode(try Self.encoded("\u{FEFF}[ti:Low Tide]")) == "[ti:Low Tide]")
        #expect(KuGouLyrics.decode("bm90IGtyYw==") == nil)
    }

    @Test func eachLineKeepsItsWordTimesWithoutTheTitleCardAndCredits() throws {
        let lyrics = try #require(KuGouLyrics.lyrics(fromKRC: Self.song, title: "Low Tide"))
        #expect(lyrics.source == .kuGou && lyrics.isSynced)
        #expect(lyrics.lines.map(\.text) == ["あい", "", "うえ"])
        #expect(lyrics.lines.map(\.time) == [1, 2.5, 10])
        #expect(
            lyrics.lines[0].words == [
                .init(text: "あ", time: 1, duration: 0.5), .init(text: "い", time: 2, duration: 0.5),
            ])
    }

    @Test func anOffsetMovesEveryTimeEarlier() throws {
        let shifted = Self.song.replacingOccurrences(of: "[offset:0]", with: "[offset:500]")
        let lyrics = try #require(KuGouLyrics.lyrics(fromKRC: shifted, title: "Low Tide"))
        #expect(lyrics.lines.map(\.time) == [0.5, 2, 9.5])
        #expect(lyrics.lines[0].words.map(\.time) == [0.5, 1.5])
    }

    @Test func aLiveRecordingIsOnlyUsedForALiveTrack() {
        let live = Self.song.replacingOccurrences(of: "[ti:Low Tide]", with: "[ti:Low Tide (Live)]")
        #expect(KuGouLyrics.lyrics(fromKRC: live, title: "Low Tide") == nil)
        #expect(KuGouLyrics.lyrics(fromKRC: live, title: "Low Tide (Live)") != nil)
        let olive = Self.song.replacingOccurrences(of: "[ti:Low Tide]", with: "[ti:Olive Tree]")
        #expect(KuGouLyrics.lyrics(fromKRC: olive, title: "Low Tide") != nil)
    }

    @Test func theWipeFollowsTheSungWordsAndWaitsBetweenThem() throws {
        let lyrics = try #require(KuGouLyrics.lyrics(fromKRC: Self.song, title: "Low Tide"))
        let progress = { (time: Double) in lyrics.moment(at: time, duration: 30)?.progress ?? -1 }
        #expect(abs(progress(1.25) - 0.25) < 1e-9)
        #expect(abs(progress(1.75) - 0.5) < 1e-9)
        #expect(abs(progress(2.4) - 0.9) < 1e-9)
        #expect(lyrics.moment(at: 1.25, duration: 30)?.remaining == 1.25)
    }

    @Test func onlyACandidateWithTheTrackTitleEditionAndLengthIsDownloaded() async throws {
        server.candidates =
            "[\(candidate("1", length: 260_000)),\(candidate("2", song: "Low")),"
            + "\(candidate("4", song: "Low Tide (Live)")),"
            + "\(candidate("3", song: "LOW TIDE (Remastered)", length: 202_000))]"
        server.files["3"] = try Self.encoded(Self.song)
        server.files["4"] = try Self.encoded(Self.song)
        let lyrics = await KuGouLyrics(load: server.answer).lyrics(for: track)
        #expect(lyrics?.lines.first?.text == "あい")
        try #require(server.asked.map(\.path) == ["/search", "/download"])
        let queries = server.asked.map { url in
            URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.reduce(into: [String: String]()) { $0[$1.name] = $1.value }
        }
        #expect(queries[0]?["keyword"] == "Harbour Lights - Low Tide")
        #expect(queries[0]?["duration"] == "201400")
        #expect(queries[1]?["id"] == "3")
    }

    @Test func aLiveTrackOnlyTakesALiveCandidate() async throws {
        server.candidates =
            "[\(candidate("1", song: "Low Tide (Remix)")),\(candidate("2")),"
            + "\(candidate("3", song: "Low Tide (ライブ)"))]"
        for id in ["1", "2", "3"] { server.files[id] = try Self.encoded(Self.song) }
        let live = MusicPlayer.Track(
            id: "L", title: "Low Tide (Live)", artist: "Harbour Lights", isPlaying: true,
            album: "Salt", duration: 201.4)
        #expect(await KuGouLyrics(load: server.answer).lyrics(for: live) != nil)
        #expect(downloaded() == ["3"])
    }

    @Test func anotherSingersRecordingIsSkipped() async throws {
        server.candidates =
            "[\(candidate("1", singer: "Someone Else")),"
            + "\(candidate("2", singer: "harbour lights、Ayase"))]"
        for id in ["1", "2"] { server.files[id] = try Self.encoded(Self.song) }
        #expect(await KuGouLyrics(load: server.answer).lyrics(for: track) != nil)
        #expect(downloaded() == ["2"])
    }

    @Test func theCandidatesAreFetchedTogetherAndTheBestRankedFileWins() async throws {
        server.candidates = "[\(candidate("1")),\(candidate("2")),\(candidate("3"))]"
        server.files["2"] = try Self.encoded(Self.song)
        server.files["3"] = try Self.encoded(
            Self.song.replacingOccurrences(of: "あ<1000,500,0>い", with: "か<1000,500,0>き"))
        let lyrics = await KuGouLyrics(load: server.answer).lyrics(for: track)
        #expect(lyrics?.lines.first?.text == "あい")
        #expect(Set(downloaded()) == ["1", "2", "3"])
    }

    @Test func aTrackWithoutALengthIsNotLookedUp() async {
        let bare = MusicPlayer.Track(id: "B", title: "Low Tide", artist: "Harbour", isPlaying: true)
        #expect(await KuGouLyrics(load: server.answer).lyrics(for: bare) == nil)
        #expect(server.asked.isEmpty)
    }

    @Test func wordTimedLyricsAreAskedForBeforeLRCLIB() async throws {
        server.candidates = "[\(candidate("3"))]"
        server.files["3"] = try Self.encoded(Self.song)
        let lrclib = Server()
        let lookup = LyricsLookup(
            load: lrclib.answer, wordTimed: [KuGouLyrics(load: server.answer).lyrics])
        let words = try #require(KuGouLyrics.lyrics(fromKRC: Self.song, title: "Low Tide"))
        #expect(try await lookup.lyrics(for: track) == .found(words))
        #expect(lrclib.asked.isEmpty)
    }

    @Test func theHighestRankedSourceWithWordsWins() async throws {
        let first = Lyrics(lines: [.init(time: 1, text: "First")], isSynced: true)
        let second = Lyrics(lines: [.init(time: 1, text: "Second")], isSynced: true)
        let lookup = LyricsLookup(
            load: Server().answer, wordTimed: [{ _ in nil }, { _ in first }, { _ in second }])
        #expect(try await lookup.lyrics(for: track) == .found(first))
    }

    @Test func lrclibAnswersWhenKuGouHasNoWords() async throws {
        let entry = "{\"duration\":201,\"instrumental\":false,\"syncedLyrics\":\"[00:01.00] Hi\"}"
        let lookup = LyricsLookup(
            load: { url in
                .init(data: Data((url.path == "/api/get" ? entry : "[]").utf8), status: 200)
            }, wordTimed: [KuGouLyrics(load: server.answer).lyrics])
        let lines = Lyrics(lines: [.init(time: 1, text: "Hi")], isSynced: true)
        #expect(try await lookup.lyrics(for: track) == .found(lines))
        #expect(server.asked.map(\.path) == ["/search"])
    }
}
