import Foundation
import Testing

@testable import AppCore

struct LyricsLookupTimingTests {
    @Test(arguments: ["album", "artist", "romanized", "translated", "failed"])
    func plainOriginalLyricsKeepSearchingForTiming(source: String) async throws {
        let plain = """
            {"duration":201,"instrumental":false,"plainLyrics":"こんにちは"}
            """
        let timed = """
            {"duration":203,"instrumental":false,"syncedLyrics":"[00:01.00] こんにちは"}
            """
        let other = source == "translated" ? "안녕하세요" : "Konnichiwa"
        let foreign = """
            {"duration":201,"instrumental":false,"syncedLyrics":"[00:01.00] \(other)"}
            """
        let lookup = LyricsLookup { url in
            if url.path == "/api/get" {
                return .init(data: Data(plain.utf8), status: 200)
            }
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let album = query.contains { $0.name == "album_name" }
            if album {
                let entry = source == "album" ? timed : plain
                return .init(data: Data("[\(entry)]".utf8), status: 200)
            }
            if source == "failed" {
                return .init(data: Data(), status: 503)
            }
            let entry = source == "romanized" || source == "translated" ? foreign : timed
            return .init(data: Data("[\(entry)]".utf8), status: 200)
        }
        let track = MusicPlayer.Track(
            id: "timing", title: "Low Tide", artist: "Harbour Lights", isPlaying: true,
            album: "Salt", duration: 201)
        let synced = source == "album" || source == "artist"
        let expected = Lyrics(
            lines: [.init(time: synced ? 1 : nil, text: "こんにちは")], isSynced: synced)
        #expect(try await lookup.lyrics(for: track) == .found(expected))
    }
}
