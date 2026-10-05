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

        var result: Outcome {
            if instrumental { return .instrumental }
            return Lyrics(synced: syncedLyrics, plain: plainLyrics).map(Outcome.found) ?? .missing
        }
    }

    private static let host = "lrclib.net"
    private static let timeout: TimeInterval = 8
    private static let httpOK = 200
    private static let httpNotFound = 404
    private static let remembered = 24
    private static let durationSlack = 3.0
    private static let agent = "Mado (https://github.com/taroj1205/mado)"

    private static let fromWeb: Load = { url in
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue(agent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    private let load: Load
    private var cache: [String: Outcome] = [:]
    private var order: [String] = []

    public init() {
        load = Self.fromWeb
    }

    init(load: @escaping Load) {
        self.load = load
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
        return try JSONDecoder().decode(LyricsEntry.self, from: data).result
    }

    private func search(_ track: MusicPlayer.Track) async throws -> Outcome? {
        let query = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist),
        ]
        guard let data = try await fetch("/api/search", query) else { return nil }
        let near = try JSONDecoder().decode([LyricsEntry].self, from: data).filter { entry in
            guard let wanted = track.duration, let actual = entry.duration else { return true }
            return abs(wanted - actual) <= Self.durationSlack
        }
        return (near.first { $0.syncedLyrics != nil } ?? near.first)?.result
    }

    private func fetch(_ path: String, _ query: [URLQueryItem]) async throws -> Data? {
        var parts = URLComponents()
        parts.scheme = "https"
        parts.host = Self.host
        parts.path = path
        parts.queryItems = query
        guard let url = parts.url else { throw Failure.badResponse }
        let (data, status) = try await load(url)
        if status == Self.httpNotFound { return nil }
        guard status == Self.httpOK else { throw Failure.badResponse }
        return data
    }

    private func remember(_ result: Outcome, as id: String) {
        cache[id] = result
        order.append(id)
        if order.count > Self.remembered { cache[order.removeFirst()] = nil }
    }
}
