import Foundation

public actor LyricsLookup {
    typealias Load = @Sendable (URL) async throws -> (data: Data, status: Int)

    public enum Outcome: Equatable, Sendable {
        case found(Lyrics)
        case instrumental
        case missing
    }

    public enum Failure: Error {
        case badResponse
    }

    private struct LyricsEntry: Decodable {
        let duration: Double?
        let instrumental: Bool
        let plainLyrics: String?
        let syncedLyrics: String?

        var lyrics: Lyrics? {
            Lyrics(synced: syncedLyrics, plain: plainLyrics)
        }

        var result: Outcome {
            if instrumental { return .instrumental }
            return lyrics.map(Outcome.found) ?? .missing
        }
    }

    private static let host = "lrclib.net"
    private static let timeout: TimeInterval = 8
    private static let httpOK = 200
    private static let httpNotFound = 404
    private static let httpTooManyRequests = 429
    private static let httpServerError = 500
    private static let retries = 2
    private static let remembered = 24
    private static let durationSlack = 3.0
    private static let titleOnlySlack = 1.0
    private static let agent = "Mado (https://github.com/taroj1205/mado)"

    private static let fromWeb: Load = { url in
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue(agent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    private let load: Load
    private let pause: Duration
    private var cache: [String: Outcome] = [:]
    private var order: [String] = []

    public init() {
        load = Self.fromWeb
        pause = .seconds(1)
    }

    init(load: @escaping Load) {
        self.load = load
        pause = .zero
    }

    private static func match(
        _ entries: [LyricsEntry], for track: MusicPlayer.Track, within slack: Double
    ) -> Outcome? {
        let gap = { (entry: LyricsEntry) -> Double in
            guard let wanted = track.duration else { return 0 }
            return entry.duration.map { abs(wanted - $0) } ?? Self.durationSlack
        }
        let near = entries.filter { gap($0) <= slack }
        let timed = near.compactMap { entry in entry.lyrics.map { (gap: gap(entry), lyrics: $0) } }
        let closest = timed.filter(\.lyrics.isSynced).min { $0.gap < $1.gap }
        if let best = closest ?? timed.first { return .found(best.lyrics) }
        return near.contains(where: \.instrumental) ? .instrumental : nil
    }

    public func lyrics(for track: MusicPlayer.Track) async throws -> Outcome {
        if let known = cache[track.id] { return known }
        var found = try await exact(track)
        if found == nil { found = try await search(track) }
        let outcome = found ?? .missing
        remember(outcome, as: track.id)
        return outcome
    }

    private func exact(_ track: MusicPlayer.Track) async throws -> Outcome? {
        guard !track.album.isEmpty, let duration = track.duration else { return nil }
        let query = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "album_name", value: track.album),
            URLQueryItem(name: "duration", value: String(Int(duration.rounded()))),
        ]
        guard let data = try await fetch("/api/get", query) else { return nil }
        let outcome = try JSONDecoder().decode(LyricsEntry.self, from: data).result
        return outcome == .missing ? nil : outcome
    }

    private func search(_ track: MusicPlayer.Track) async throws -> Outcome? {
        let named = try await hits(track, artist: track.artist)
        if let match = Self.match(named, for: track, within: Self.durationSlack) { return match }
        if track.duration != nil {
            let titled = try await hits(track, artist: nil).filter { !$0.instrumental }
            if let match = Self.match(titled, for: track, within: Self.titleOnlySlack) {
                return match
            }
        }
        return named.lazy.compactMap { Lyrics(synced: nil, plain: $0.plainLyrics) }.first
            .map(Outcome.found)
    }

    private func hits(_ track: MusicPlayer.Track, artist: String?) async throws -> [LyricsEntry] {
        var query = [URLQueryItem(name: "track_name", value: track.title)]
        if let artist { query.append(URLQueryItem(name: "artist_name", value: artist)) }
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
            let (data, status) = try await load(url)
            if status == Self.httpOK { return data }
            if status == Self.httpNotFound { return nil }
            let busy = status == Self.httpTooManyRequests || status >= Self.httpServerError
            guard busy, attempt < Self.retries else { break }
            try await Task.sleep(for: pause * (attempt + 1))
        }
        throw Failure.badResponse
    }

    private func remember(_ result: Outcome, as id: String) {
        cache[id] = result
        order.append(id)
        if order.count > Self.remembered { cache[order.removeFirst()] = nil }
    }
}
