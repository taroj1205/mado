import Foundation
import os

@MainActor
public final class NowPlaying {
    public enum User: Hashable, Sendable {
        case launcher
        case stage
    }

    private static let listenSeconds = 2
    private static let followMilliseconds = 250
    private static let listen = Duration.seconds(listenSeconds)
    private static let follow = Duration.milliseconds(followMilliseconds)

    public let session: LyricsSession
    public private(set) var track: MusicPlayer.Track?
    public var onChange: (() -> Void)?
    public var lookup = false {
        didSet { if lookup != oldValue { restart() } }
    }
    public var players = Set(MusicPlayer.Player.allCases) {
        didSet { if players != oldValue { restart() } }
    }

    private let logger = Log.logger("NowPlaying")
    private let source: any NowPlayingSource
    private let uptime: @MainActor () -> TimeInterval
    private let rhythm: (listen: Duration, follow: Duration)
    private var users: Set<User> = []
    private var loops: [Task<Void, Never>] = []
    private var line: Int?
    private var latest = 0

    public var isRunning: Bool {
        !users.isEmpty
    }

    public convenience init() {
        self.init(
            source: MusicPlayer(), session: LyricsSession(), rhythm: (Self.listen, Self.follow)
        ) { ProcessInfo.processInfo.systemUptime }
    }

    init(
        source: any NowPlayingSource, session: LyricsSession,
        rhythm: (listen: Duration, follow: Duration),
        uptime: @escaping @MainActor () -> TimeInterval
    ) {
        self.source = source
        self.session = session
        self.rhythm = rhythm
        self.uptime = uptime
        session.onChange = { [weak self] in self?.onChange?() }
    }

    public func start(_ user: User) {
        let wasRunning = isRunning
        users.insert(user)
        if !wasRunning { begin() }
    }

    public func stop(_ user: User) {
        users.remove(user)
        if !isRunning { end() }
    }

    public func perform(_ control: MusicPlayer.Control) async {
        do {
            await apply(try await source.perform(control))
        } catch {
            logger.error("Music control failed: \(error, privacy: .private)")
        }
    }

    public func seek(toLine index: Int) async {
        guard let start = session.start(ofLine: index), track != nil else { return }
        do {
            try await source.seek(to: start)
            session.moved(to: start, isPlaying: track?.isPlaying ?? false, at: uptime())
            line = session.moment(at: uptime())?.index
            onChange?()
        } catch {
            logger.error("Seek failed: \(error, privacy: .private)")
        }
    }

    private func restart() {
        guard isRunning else { return }
        end()
        begin()
    }

    private func begin() {
        loops = [
            Task { [weak self] in
                while !Task.isCancelled {
                    await self?.poll()
                    try? await Task.sleep(for: self?.rhythm.listen ?? Self.listen)
                }
            },
            Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: self?.rhythm.follow ?? Self.follow)
                    self?.advance()
                }
            },
        ]
    }

    private func end() {
        loops.forEach { $0.cancel() }
        loops = []
    }

    private func allows(_ found: MusicPlayer.Track?) -> Bool {
        lookup && (found.map { players.contains($0.player) } ?? true)
    }

    private func poll() async {
        await apply(await source.track())
    }

    private func apply(_ found: MusicPlayer.Track?) async {
        guard isRunning else {
            track = found
            onChange?()
            return
        }
        latest += 1
        let mine = latest
        let enabled = allows(found)
        let position = found != nil && enabled ? await source.position() : nil
        guard !Task.isCancelled, isRunning, mine == latest else { return }
        track = found
        session.update(found, position: position, enabled: enabled, at: uptime())
        line = session.moment(at: uptime())?.index
        onChange?()
    }

    private func advance() {
        let current = session.moment(at: uptime())?.index
        guard current != line else { return }
        line = current
        onChange?()
    }
}
