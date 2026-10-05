public import Foundation
import os

@MainActor
public final class LyricsSession {
    public enum State: Equatable, Sendable {
        case off
        case idle
        case loading
        case found(Lyrics)
        case instrumental
        case missing
        case failed
    }

    private static let retryAfter: TimeInterval = 60

    public var onChange: (() -> Void)?
    public private(set) var state = State.idle {
        didSet {
            if state != oldValue { onChange?() }
        }
    }

    private let logger = Log.logger("Lyrics")
    private let lookup: LyricsLookup
    private var clock = LyricsClock()
    private var duration: TimeInterval?
    private var fetching: (id: String, task: Task<Void, Never>)?
    private var tried: (id: String, at: TimeInterval)?

    public var length: TimeInterval? {
        duration
    }

    public var lyrics: Lyrics? {
        if case .found(let found) = state { found } else { nil }
    }

    var pending: Task<Void, Never>? {
        fetching?.task
    }

    public init() {
        lookup = LyricsLookup()
    }

    init(lookup: LyricsLookup) {
        self.lookup = lookup
    }

    public func update(
        _ track: MusicPlayer.Track?, position: TimeInterval?, enabled: Bool, at now: TimeInterval
    ) {
        guard enabled, let track else {
            fetching?.task.cancel()
            fetching = nil
            tried = nil
            state = enabled ? .idle : .off
            return
        }
        duration = track.duration
        if let position {
            clock.sync(position: position, at: now, isPlaying: track.isPlaying)
        }
        if fetching?.id == track.id { return }
        let retryable = state == .failed && now - (tried?.at ?? 0) >= Self.retryAfter
        if tried?.id == track.id, !retryable { return }
        fetch(track, at: now)
    }

    public func position(at now: TimeInterval) -> TimeInterval {
        clock.position(at: now)
    }

    public func moment(at now: TimeInterval) -> Lyrics.Moment? {
        lyrics?.moment(at: clock.position(at: now), duration: duration)
    }

    public func start(ofLine line: Int) -> TimeInterval? {
        guard let lyrics, lyrics.isSynced, lyrics.lines.indices.contains(line) else { return nil }
        return lyrics.lines[line].time
    }

    public func moved(to position: TimeInterval, isPlaying: Bool, at now: TimeInterval) {
        clock.sync(position: position, at: now, isPlaying: isPlaying)
    }

    private func fetch(_ track: MusicPlayer.Track, at now: TimeInterval) {
        fetching?.task.cancel()
        state = .loading
        tried = (track.id, now)
        let id = track.id
        fetching = (
            id,
            Task { [lookup] in
                do {
                    let found = try await lookup.lyrics(for: track)
                    finish(id, found)
                } catch {
                    guard !Task.isCancelled else { return }
                    logger.error("Lyrics lookup failed: \(error, privacy: .public)")
                    finish(id, nil)
                }
            }
        )
    }

    private func finish(_ id: String, _ found: LyricsLookup.Outcome?) {
        guard fetching?.id == id, !Task.isCancelled else { return }
        fetching = nil
        state =
            switch found {
            case .found(let lyrics): .found(lyrics)
            case .instrumental: .instrumental
            case .missing: .missing
            case nil: .failed
            }
    }
}
