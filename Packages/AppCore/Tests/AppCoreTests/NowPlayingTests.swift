import Foundation
import Testing

@testable import AppCore

@MainActor
@Suite struct NowPlayingTests {
    private actor Player: NowPlayingSource {
        var current: MusicPlayer.Track?
        var time: TimeInterval? = 12
        private(set) var tracked = 0
        private(set) var positioned = 0
        private(set) var seeks: [TimeInterval] = []
        private(set) var controls: [MusicPlayer.Control] = []

        func play(_ track: MusicPlayer.Track?) {
            current = track
        }

        func set(position: TimeInterval) {
            time = position
        }

        func track(among _: Set<MusicPlayer.Player>) -> MusicPlayer.Track? {
            tracked += 1
            return current
        }

        func position() -> TimeInterval? {
            positioned += 1
            return time
        }

        func seek(to seconds: TimeInterval) {
            seeks.append(seconds)
        }

        func perform(_ control: MusicPlayer.Control) -> MusicPlayer.Track? {
            controls.append(control)
            return current
        }
    }

    private final class Server: @unchecked Sendable {
        var asked = 0

        func answer(_: URL) -> LyricsLookup.Reply {
            asked += 1
            let body = """
                {"duration":200,"instrumental":false,"plainLyrics":"A\\nB",
                "syncedLyrics":"[00:10.00] A\\n[00:20.00] B"}
                """
            return .init(data: Data(body.utf8), status: 200)
        }
    }

    private let player = Player()
    private let server = Server()
    private let nowPlaying: NowPlaying
    private let song = MusicPlayer.Track(
        id: "A1", title: "Low Tide", artist: "Harbour Lights", isPlaying: true, album: "Salt",
        duration: 200)

    init() {
        let session = LyricsSession(lookup: LyricsLookup { [server] url in server.answer(url) })
        nowPlaying = NowPlaying(
            source: player, session: session, rhythm: (.milliseconds(10), .milliseconds(5)),
            changes: NotificationCenter()
        ) { ProcessInfo.processInfo.systemUptime }
    }

    private func until(_ done: @MainActor () async -> Bool) async -> Bool {
        for _ in 0..<400 {
            if await done() { return true }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return false
    }

    @Test func aRunningFeedPollsThePlayerAndPublishesTheTrack() async {
        await player.play(song)
        nowPlaying.lookup = true
        var changes = 0
        nowPlaying.onChange = { changes += 1 }
        nowPlaying.start(.stage)
        #expect(await until { nowPlaying.session.lyrics != nil })
        #expect(nowPlaying.track == song)
        #expect(changes > 0)
        nowPlaying.stop(.stage)
    }

    @Test func theLauncherAndTheStageShareOneLoop() async {
        await player.play(song)
        nowPlaying.start(.launcher)
        nowPlaying.start(.stage)
        #expect(await until { await player.tracked >= 3 })
        nowPlaying.stop(.launcher)
        #expect(nowPlaying.isRunning)
        let before = await player.tracked
        #expect(await until { await player.tracked > before })
        nowPlaying.stop(.stage)
        #expect(!nowPlaying.isRunning)
    }

    @Test func stoppingTheLastUserStopsPolling() async {
        nowPlaying.start(.stage)
        #expect(await until { await player.tracked >= 2 })
        nowPlaying.stop(.stage)
        try? await Task.sleep(for: .milliseconds(30))
        let settled = await player.tracked
        try? await Task.sleep(for: .milliseconds(60))
        #expect(await player.tracked == settled)
    }

    @Test func withLookupOffNothingIsAskedOrSent() async {
        await player.play(song)
        nowPlaying.start(.stage)
        #expect(await until { nowPlaying.track != nil })
        #expect(nowPlaying.session.state == .off)
        #expect(await player.positioned == 0)
        #expect(server.asked == 0)
        nowPlaying.stop(.stage)
    }

    @Test func aPlayerThatIsTurnedOffIsNotLookedUp() async {
        let spotify = MusicPlayer.Track(
            id: "S1", title: "Low Tide", artist: "Harbour Lights", isPlaying: true, album: "Salt",
            duration: 200, player: .spotify)
        await player.play(spotify)
        nowPlaying.players = [.music]
        nowPlaying.lookup = true
        nowPlaying.start(.stage)
        #expect(await until { nowPlaying.track != nil })
        #expect(nowPlaying.session.state == .off)
        #expect(server.asked == 0)
        nowPlaying.stop(.stage)
    }

    @Test func turningLookupOnLooksUpTheSongAtOnceWithoutWaitingForTheNextPoll() async {
        await player.play(song)
        nowPlaying.start(.stage)
        #expect(await until { nowPlaying.track != nil })
        nowPlaying.lookup = true
        #expect(await until { nowPlaying.session.lyrics != nil })
        nowPlaying.stop(.stage)
    }

    @Test func crossingALineBoundaryTellsTheObservers() async {
        await player.play(song)
        nowPlaying.lookup = true
        nowPlaying.start(.stage)
        #expect(await until { nowPlaying.session.lyrics != nil })
        var lines: [Int?] = []
        nowPlaying.onChange = {
            lines.append(nowPlaying.session.moment(at: ProcessInfo.processInfo.systemUptime)?.index)
        }
        await player.set(position: 19.99)
        nowPlaying.session.moved(
            to: 19.99, isPlaying: true, at: ProcessInfo.processInfo.systemUptime)
        #expect(await until { lines.contains(1) })
        nowPlaying.stop(.stage)
    }

    @Test func eachLineChangesWhenItIsDueNotOnTheNextTick() async throws {
        let stamps = ["10.00", "10.37", "10.74", "11.11", "11.48", "11.85"]
        let starts = stamps.compactMap(Double.init)
        let synced = stamps.enumerated().map { "[00:\($1)] Line \($0)" }.joined(separator: "\n")
        let body = try JSONSerialization.data(withJSONObject: [
            "duration": 200, "instrumental": false, "syncedLyrics": synced,
        ])
        let session = LyricsSession(
            lookup: LyricsLookup { url in
                .init(
                    data: url.path == "/api/search" ? Data("[".utf8) + body + Data("]".utf8) : body,
                    status: 200)
            })
        let ticking = NowPlaying(
            source: player, session: session, rhythm: (.seconds(10), .milliseconds(500)),
            changes: NotificationCenter()
        ) { ProcessInfo.processInfo.systemUptime }
        await player.play(song)
        await player.set(position: 9.1)
        ticking.lookup = true
        var lateness: [Int: TimeInterval] = [:]
        ticking.onChange = {
            let now = ProcessInfo.processInfo.systemUptime
            guard let index = session.moment(at: now)?.index, lateness[index] == nil else { return }
            lateness[index] = session.position(at: now) + 0.3 - starts[index]
        }
        ticking.start(.stage)
        defer { ticking.stop(.stage) }
        for _ in 0..<100 where lateness.count < starts.count {
            try? await Task.sleep(for: .milliseconds(50))
        }
        #expect(lateness.count == starts.count)
        #expect(lateness.values.allSatisfy { $0 > -0.01 && $0 < 0.15 })
    }

    @Test func aPlayerChangeIsPolledAtOnceWhileRunning() async {
        let changes = NotificationCenter()
        let spotifyChanged = MusicPlayer.Player.spotify.changeNotification
        let listening = NowPlaying(
            source: player,
            session: LyricsSession(lookup: LyricsLookup { [server] url in server.answer(url) }),
            rhythm: (.seconds(10), .seconds(10)), changes: changes
        ) { ProcessInfo.processInfo.systemUptime }
        changes.post(name: spotifyChanged, object: nil)
        try? await Task.sleep(for: .milliseconds(30))
        #expect(await player.tracked == 0)
        listening.start(.stage)
        #expect(await until { await player.tracked == 1 })
        await player.play(song)
        changes.post(name: spotifyChanged, object: nil)
        #expect(await until { listening.track == song })
        listening.stop(.stage)
        let settled = await player.tracked
        changes.post(name: spotifyChanged, object: nil)
        try? await Task.sleep(for: .milliseconds(30))
        #expect(await player.tracked == settled)
    }

    @Test func seekingToALineMovesThePlayerAndTheClock() async {
        await player.play(song)
        nowPlaying.lookup = true
        nowPlaying.start(.stage)
        #expect(await until { nowPlaying.session.lyrics != nil })
        await nowPlaying.seek(toLine: 1)
        #expect(await player.seeks == [20])
        #expect(
            nowPlaying.session.moment(at: ProcessInfo.processInfo.systemUptime)?.index == 1)
        nowPlaying.stop(.stage)
    }

    @Test func seekingInAPausedTrackAlsoResumesIt() async {
        let paused = MusicPlayer.Track(
            id: "A1", title: "Low Tide", artist: "Harbour Lights", isPlaying: false, album: "Salt",
            duration: 200)
        await player.play(paused)
        nowPlaying.lookup = true
        nowPlaying.start(.stage)
        defer { nowPlaying.stop(.stage) }
        #expect(await until { nowPlaying.session.lyrics != nil })
        await nowPlaying.seek(toLine: 1)
        #expect(await player.seeks == [20])
        #expect(await player.controls == [.playPause])
    }

    @Test func seekingWithoutTimedLinesDoesNothing() async {
        await nowPlaying.seek(toLine: 0)
        #expect(await player.seeks.isEmpty)
    }

    @Test func aControlGoesToThePlayerAndRefreshesTheTrack() async {
        await player.play(song)
        var changes = 0
        nowPlaying.onChange = { changes += 1 }
        await nowPlaying.perform(.next)
        #expect(await player.controls == [.next])
        #expect(nowPlaying.track == song)
        #expect(changes > 0)
    }

    @Test func aControlLooksUpTheLyricsOfTheTrackItBrings() async {
        await player.play(song)
        nowPlaying.lookup = true
        nowPlaying.start(.launcher)
        defer { nowPlaying.stop(.launcher) }
        await nowPlaying.perform(.next)
        #expect(await until { nowPlaying.session.lyrics != nil })
        #expect(server.asked == 2)
    }

    @Test func aControlThatLandsAfterPollingStoppedOnlyUpdatesTheTrack() async {
        await player.play(song)
        nowPlaying.lookup = true
        await nowPlaying.perform(.next)
        #expect(nowPlaying.track == song)
        #expect(await player.positioned == 0)
        #expect(nowPlaying.session.state == .idle)
        #expect(server.asked == 0)
    }
}
