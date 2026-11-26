import Foundation

struct BetterLyrics: Sendable {
    private struct Reply: Decodable {
        let ttml: String
    }

    private static let host = "api.betterlyrics.org"
    private static let durationSlack = 3.0

    private let load: LyricsLookup.Load

    init(load: @escaping LyricsLookup.Load) {
        self.load = load
    }

    static func lyrics(fromTTML text: String, duration: TimeInterval) -> Lyrics? {
        let reader = TTMLReader()
        let parser = XMLParser(data: Data(text.utf8))
        unsafe parser.delegate = reader
        guard parser.parse(), reader.isWordTimed, let length = reader.length,
            abs(length - duration) <= durationSlack, !reader.lines.isEmpty
        else { return nil }
        return Lyrics(sung: reader.lines, source: .betterLyrics)
    }

    func lyrics(for track: MusicPlayer.Track) async -> Lyrics? {
        guard let duration = track.duration,
            let reply: Reply = try? await LyricsLookup.json(
                from: load, host: Self.host, path: "/getLyrics",
                query: [
                    "s": track.title, "a": track.artist,
                    "d": String(Int(duration.rounded())),
                ])
        else { return nil }
        return Self.lyrics(fromTTML: reply.ttml, duration: duration)
    }
}
