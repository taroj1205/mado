import Compression
import Foundation

struct KuGouLyrics: Sendable {
    private struct Candidate: Decodable {
        let id: String
        let accesskey: String
        let song: String
        let duration: Double
    }

    private struct Search: Decodable {
        let candidates: [Candidate]
    }

    private struct Download: Decodable {
        let content: String
    }

    private static let host = "lyrics.kugou.com"
    private static let milliseconds = 1_000.0
    private static let durationSlack = 3.0
    private static let triedCandidates = 3
    private static let magic = Data("krc1".utf8)
    private static let key = "@Gaw^2tGQ61-\u{CE}\u{D2}ni".unicodeScalars.map { scalar in
        UInt8(truncatingIfNeeded: scalar.value)
    }
    private static let zlibHeader = 2
    private static let byteOrderMark = "\u{FEFF}"
    private static let editionAliases = ["ライブ": "live", "现场": "live", "伴奏": "instrumental"]
    private static let same: String.CompareOptions = [
        .caseInsensitive, .diacriticInsensitive, .widthInsensitive,
    ]

    private let load: LyricsLookup.Load

    init(load: @escaping LyricsLookup.Load) {
        self.load = load
    }

    static func decode(_ content: String) -> String? {
        guard let data = Data(base64Encoded: content, options: .ignoreUnknownCharacters),
            data.starts(with: magic)
        else { return nil }
        let plain = Data(
            data.dropFirst(magic.count).enumerated().map { $1 ^ key[$0 % key.count] })
        var inflated = Data()
        do {
            let filter = try OutputFilter(.decompress, using: .zlib) { chunk in
                inflated.append(chunk ?? Data())
            }
            try filter.write(plain.dropFirst(zlibHeader))
            try filter.finalize()
        } catch {
            return nil
        }
        return String(bytes: inflated, encoding: .utf8)?
            .replacingOccurrences(of: byteOrderMark, with: "")
    }

    static func lyrics(fromKRC text: String, title: String) -> Lyrics? {
        let rows = text.split(whereSeparator: \.isNewline)
        let named = rows.lazy.compactMap { $0.wholeMatch(of: /\[ti:(.*)\]/)?.1 }.first ?? ""
        guard editions(of: String(named)).isSubset(of: editions(of: title)) else { return nil }
        let offset = rows.lazy.compactMap { $0.wholeMatch(of: /\[offset:(-?\d+)\]/)?.1 }.first
        let shift = offset.flatMap { Double($0) }.map { $0 / milliseconds } ?? 0
        let sung = rows.compactMap { line($0, shift: shift) }.drop(while: isCredit)
        guard !sung.isEmpty else { return nil }
        return Lyrics(sung: Array(sung), source: .kuGou)
    }

    private static func line(_ row: Substring, shift: TimeInterval) -> Lyrics.Line? {
        guard let head = row.wholeMatch(of: /\[(\d+),\d+\](.*)/), let start = Double(head.1)
        else { return nil }
        let words = head.2.matches(of: /<(\d+),(\d+),-?\d+>([^<]*)/).compactMap { tag in
            Double(tag.1).flatMap { offset in
                Double(tag.2).map { length in
                    Lyrics.Word(
                        text: String(tag.3), time: (start + offset) / milliseconds - shift,
                        duration: length / milliseconds)
                }
            }
        }
        let text = words.map(\.text).joined()
        guard !text.allSatisfy(\.isWhitespace) else { return nil }
        return Lyrics.Line(time: start / milliseconds - shift, text: text, words: words)
    }

    private static func bare(_ title: String) -> String {
        let suffix = title.firstRange(of: /\ - |\s*[(（\[【]/)?.lowerBound ?? title.endIndex
        return title[..<suffix].trimmingCharacters(in: .whitespaces)
    }

    private static func editions(of name: String) -> Set<String> {
        let marker = /(?i)\b(live|remix|instrumental)\b|ライブ|现场|伴奏/
        return Set(
            name.matches(of: marker).map { match in
                let word = match.output.0.lowercased()
                return editionAliases[word, default: word]
            })
    }

    private static func isCredit(_ line: Lyrics.Line) -> Bool {
        line.text.contains(" - ") || line.text.contains(":") || line.text.contains("：")
    }

    private func fetch<Body: Decodable>(
        _ path: String, _ query: [String: String]
    ) async throws -> Body {
        try await LyricsLookup.json(
            from: load, host: Self.host, path: path,
            query: query.merging(["ver": "1", "client": "pc"]) { $1 })
    }

    func lyrics(for track: MusicPlayer.Track) async -> Lyrics? {
        guard let duration = track.duration,
            let found: Search = try? await fetch(
                "/search",
                [
                    "keyword": "\(track.artist) - \(track.title)",
                    "duration": String(Int((duration * Self.milliseconds).rounded())),
                    "man": "yes", "hash": "",
                ])
        else { return nil }
        let title = Self.bare(track.title)
        let near = found.candidates.filter { candidate in
            abs(candidate.duration / Self.milliseconds - duration) <= Self.durationSlack
                && Self.bare(candidate.song).compare(title, options: Self.same) == .orderedSame
                && Self.editions(of: candidate.song) == Self.editions(of: track.title)
        }
        for candidate in near.prefix(Self.triedCandidates) {
            guard
                let file: Download = try? await fetch(
                    "/download",
                    [
                        "id": candidate.id, "accesskey": candidate.accesskey, "fmt": "krc",
                        "charset": "utf8",
                    ]),
                let text = Self.decode(file.content),
                let lyrics = Self.lyrics(fromKRC: text, title: track.title)
            else { continue }
            return lyrics
        }
        return nil
    }
}
