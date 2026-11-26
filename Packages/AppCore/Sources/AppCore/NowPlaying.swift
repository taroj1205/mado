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
    private static let landing: TimeInterval = 0.005

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
    private let changes: NotificationCenter
    private var users: Set<User> = []
    private var loops: [Task<Void, Never>] = []
    private var observers: [any NSObjectProtocol] = []
    private var line: Int?
    private var latest = 0

    public var isRunning: Bool {
        !users.isEmpty
    }

    public convenience init() {
        self.init(
            source: MusicPlayer(), session: LyricsSession(), rhythm: (Self.listen, Self.follow),
            changes: DistributedNotificationCenter.default()
        ) { ProcessInfo.processInfo.systemUptime }
    }

    init(
        source: any NowPlayingSource, session: LyricsSession,
        rhythm: (listen: Duration, follow: Duration), changes: NotificationCenter,
        uptime: @escaping @MainActor () -> TimeInterval
    ) {
        self.source = source
        self.session = session
        self.rhythm = rhythm
        self.changes = changes
        self.uptime = uptime
        session.onChange = { [weak self] in self?.onChange?() }
    }

    static func wake(in seconds: TimeInterval?, cappedAt cap: Duration) -> Duration {
        guard let seconds else { return cap }
        return .seconds(min(cap / .seconds(1), seconds + landing))
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
            let found = try await source.perform(control)
            await apply(found, as: nextTicket())
        } catch {
            logger.error("Music control failed: \(error, privacy: .private)")
        }
    }

    public func seek(toLine index: Int) async {
        guard let start = session.start(ofLine: index), track != nil else { return }
        do {
            let wasPaused = track?.isPlaying == false
            try await source.seek(to: start)
            if wasPaused {
                let found = try await source.perform(.playPause)
                await apply(found, as: nextTicket())
            }
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
        observers = players.map { player in
            changes.addObserver(
                forName: player.changeNotification, object: nil, queue: nil
            ) { [weak self] _ in Task { await self?.poll() } }
        }
        loops = [
            Task { [weak self] in
                while !Task.isCancelled {
                    await self?.poll()
                    try? await Task.sleep(for: self?.rhythm.listen ?? Self.listen)
                }
            },
            Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: self?.nextWake() ?? Self.follow)
                    self?.advance()
                }
            },
        ]
    }

    private func end() {
        loops.forEach { $0.cancel() }
        loops = []
        observers.forEach { changes.removeObserver($0) }
        observers = []
    }

    private func allows(_ found: MusicPlayer.Track?) -> Bool {
        lookup && (found.map { players.contains($0.player) } ?? true)
    }

    private func poll() async {
        let ticket = nextTicket()
        await apply(await source.track(among: players), as: ticket)
    }

    private func nextTicket() -> Int {
        latest += 1
        return latest
    }

    private func apply(_ found: MusicPlayer.Track?, as ticket: Int) async {
        guard ticket == latest else { return }
        guard isRunning else {
            track = found
            onChange?()
            return
        }
        let enabled = allows(found)
        let position = found != nil && enabled ? await source.position() : nil
        guard !Task.isCancelled, isRunning, ticket == latest else { return }
        track = found
        session.update(found, position: position, enabled: enabled, at: uptime())
        line = session.moment(at: uptime())?.index
        onChange?()
    }

    private func nextWake() -> Duration {
        Self.wake(in: session.untilNextLine(at: uptime()), cappedAt: rhythm.follow)
    }

    private func advance() {
        let current = session.moment(at: uptime())?.index
        guard current != line else { return }
        line = current
        onChange?()
    }
}
