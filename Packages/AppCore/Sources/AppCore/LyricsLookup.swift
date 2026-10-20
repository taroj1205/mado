import Foundation

public actor LyricsLookup {
    typealias Load = @Sendable (URL) async throws -> Reply

    struct Reply: Sendable {
        let data: Data
        let status: Int
        var retryAfter: TimeInterval?
    }

    public enum Outcome: Equatable, Sendable {
        case found(Lyrics)
        case instrumental
        case missing

        var isFinal: Bool {
            switch self {
            case .found(let lyrics): LyricsLanguage(detecting: lyrics) != nil
            case .instrumental: true
            case .missing: false
            }
        }
    }

    public enum Failure: Error {
        case badResponse
    }

    private struct LyricsEntry: Decodable {
        let trackName: String?
        let duration: Double?
        let instrumental: Bool
        let plainLyrics: String?
        let syncedLyrics: String?

        var lyrics: Lyrics? {
            Lyrics(synced: syncedLyrics, plain: plainLyrics)
        }

        var isInOriginalLanguage: Bool {
            lyrics.map { LyricsLanguage(detecting: $0) != nil } ?? false
        }

        func isTitled(_ title: String) -> Bool {
            let same: String.CompareOptions = [
                .caseInsensitive, .diacriticInsensitive, .widthInsensitive,
            ]
            return trackName?.compare(title, options: same) == .orderedSame
        }
    }

    private static let host = "lrclib.net"
    private static let timeout: TimeInterval = 8
    private static let httpOK = 200
    private static let httpNotFound = 404
    private static let httpTooManyRequests = 429
    private static let httpServerError = 500
    private static let retries = 2
    private static let longestWait: TimeInterval = 10
    private static let remembered = 24
    private static let durationSlack = 3.0
    private static let titleOnlySlack = 1.0
    private static let agent = "Mado (https://github.com/taroj1205/mado)"

    private static let fromWeb: Load = { url in
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue(agent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as? HTTPURLResponse
        let header = http?.value(forHTTPHeaderField: "Retry-After")
        return Reply(
            data: data, status: http?.statusCode ?? 0,
            retryAfter: header.map { Double($0) ?? .infinity })
    }

    private let load: Load
    private let pause: TimeInterval
    private var cache: [String: Outcome] = [:]
    private var order: [String] = []

    public init() {
        load = Self.fromWeb
        pause = 1
    }

    init(load: @escaping Load) {
        self.load = load
        pause = 0
    }

    private static func match(
        _ entries: [LyricsEntry], for track: MusicPlayer.Track, within slack: Double
    ) -> Outcome? {
        let gap = { (entry: LyricsEntry) -> Double in
            guard let wanted = track.duration else { return 0 }
            return entry.duration.map { abs(wanted - $0) } ?? Self.durationSlack
        }
        let near = entries.filter { gap($0) <= slack }
        let timed = near.compactMap { entry in
            entry.lyrics.map { lyrics in
                (gap: gap(entry), lyrics: lyrics, language: LyricsLanguage(detecting: lyrics))
            }
        }
        let original = LyricsLanguage.prevailing(in: timed.compactMap(\.language))
        let pool = original.map { language in timed.filter { $0.language == language } } ?? timed
        let closest = pool.filter(\.lyrics.isSynced).min { $0.gap < $1.gap }
        if let best = closest ?? pool.first { return .found(best.lyrics) }
        return near.contains(where: \.instrumental) ? .instrumental : nil
    }

    public func lyrics(for track: MusicPlayer.Track) async throws -> Outcome {
        if let known = cache[track.id] { return known }
        let outcome = try await find(track) ?? .missing
        remember(outcome, as: track.id)
        return outcome
    }

    private func find(_ track: MusicPlayer.Track) async throws -> Outcome? {
        let exact = try await exact(track).map { [$0] } ?? []
        let known = Self.match(exact, for: track, within: Self.durationSlack)
        if known?.isFinal == true { return known }
        let original = await sameAlbum(track).filter(\.isInOriginalLanguage)
        if let match = Self.match(original, for: track, within: Self.durationSlack) { return match }
        if known != nil { return known }
        return try await search(track)
    }

    private func exact(_ track: MusicPlayer.Track) async throws -> LyricsEntry? {
        guard !track.album.isEmpty, let duration = track.duration else { return nil }
        let query = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "album_name", value: track.album),
            URLQueryItem(name: "duration", value: String(Int(duration.rounded()))),
        ]
        guard let data = try await fetch("/api/get", query) else { return nil }
        return try JSONDecoder().decode(LyricsEntry.self, from: data)
    }

    private func sameAlbum(_ track: MusicPlayer.Track) async -> [LyricsEntry] {
        guard !track.album.isEmpty else { return [] }
        return (try? await hits(track, artist: nil, album: track.album)) ?? []
    }

    private func search(_ track: MusicPlayer.Track) async throws -> Outcome? {
        let named = try await hits(track, artist: track.artist)
        if let match = Self.match(named, for: track, within: Self.durationSlack) { return match }
        let plain = named.lazy.compactMap { Lyrics(synced: nil, plain: $0.plainLyrics) }.first
            .map(Outcome.found)
        if track.duration != nil {
            do {
                let titled = try await hits(track, artist: nil)
                    .filter { !$0.instrumental && $0.isTitled(track.title) }
                if let match = Self.match(titled, for: track, within: Self.titleOnlySlack) {
                    return match
                }
            } catch _ where plain != nil {
                return plain
            }
        }
        return plain
    }

    private func hits(
        _ track: MusicPlayer.Track, artist: String?, album: String? = nil
    ) async throws -> [LyricsEntry] {
        var query = [URLQueryItem(name: "track_name", value: track.title)]
        if let artist { query.append(URLQueryItem(name: "artist_name", value: artist)) }
        if let album { query.append(URLQueryItem(name: "album_name", value: album)) }
        guard let data = try await fetch("/api/search", query) else { return [] }
        return try JSONDecoder().decode([LyricsEntry].self, from: data)
    }

    private func fetch(_ path: String, _ query: [URLQueryItem]) async throws -> Data? {
        var parts = URLComponents()
        parts.scheme = "https"
        parts.host = Self.host
        parts.path = path
        parts.queryItems = query
        guard let url = parts.url else { throw Failure.badResponse }
        for attempt in 0...Self.retries {
            let reply = try await load(url)
            if reply.status == Self.httpOK { return reply.data }
            if reply.status == Self.httpNotFound { return nil }
            let busy =
                reply.status == Self.httpTooManyRequests || reply.status >= Self.httpServerError
            let wait = reply.retryAfter ?? pause * Double(attempt + 1)
            guard busy, attempt < Self.retries, wait <= Self.longestWait else { break }
            try await Task.sleep(for: .seconds(wait))
        }
        throw Failure.badResponse
    }

    private func remember(_ result: Outcome, as id: String) {
        cache[id] = result
        order.append(id)
        if order.count > Self.remembered { cache[order.removeFirst()] = nil }
    }
}
