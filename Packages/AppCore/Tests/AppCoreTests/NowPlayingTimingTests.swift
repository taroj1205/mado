import Foundation
import Testing

@testable import AppCore

@MainActor
@Suite struct NowPlayingTimingTests {
    private actor Racing: NowPlayingSource {
        let older: MusicPlayer.Track
        let newer: MusicPlayer.Track
        private var reads = 0
        private var held: CheckedContinuation<Void, Never>?

        var isHolding: Bool {
            held != nil
        }

        init(older: MusicPlayer.Track, newer: MusicPlayer.Track) {
            self.older = older
            self.newer = newer
        }

        func track(among _: Set<MusicPlayer.Player>) async -> MusicPlayer.Track? {
            reads += 1
            guard reads == 1 else { return newer }
            await withCheckedContinuation { held = $0 }
            return older
        }

        func release() {
            held?.resume()
            held = nil
        }

        func position() -> TimeInterval? {
            nil
        }

        func seek(to _: TimeInterval) throws {
            throw MusicPlayer.Failure.noTrack
        }

        func perform(_: MusicPlayer.Control) -> MusicPlayer.Track? {
            nil
        }
    }

    private let older = MusicPlayer.Track(
        id: "A1", title: "Low Tide", artist: "Harbour Lights", isPlaying: true, album: "Salt",
        duration: 200, player: .spotify)
    private let newer = MusicPlayer.Track(
        id: "B2", title: "High Water", artist: "Harbour Lights", isPlaying: true, album: "Salt",
        duration: 180, player: .spotify)

    private func until(_ done: @MainActor () async -> Bool) async -> Bool {
        for _ in 0..<400 {
            if await done() { return true }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return false
    }

    @Test func theWaitIsCappedBeforeItBecomesADuration() {
        let cap = Duration.milliseconds(250)
        #expect(NowPlaying.wake(in: nil, cappedAt: cap) == cap)
        #expect(NowPlaying.wake(in: 1e100, cappedAt: cap) == cap)
        #expect(NowPlaying.wake(in: .infinity, cappedAt: cap) == cap)
        #expect(abs(NowPlaying.wake(in: 0.095, cappedAt: cap) / .seconds(1) - 0.1) < 1e-9)
    }

    @Test func anOlderPollThatFinishesLastDoesNotWin() async {
        let source = Racing(older: older, newer: newer)
        let changes = NotificationCenter()
        let nowPlaying = NowPlaying(
            source: source,
            session: LyricsSession(lookup: LyricsLookup { _ in .init(data: Data(), status: 404) }),
            rhythm: (.seconds(10), .seconds(10)), changes: changes
        ) { ProcessInfo.processInfo.systemUptime }
        nowPlaying.start(.stage)
        defer { nowPlaying.stop(.stage) }
        #expect(await until { await source.isHolding })
        changes.post(name: MusicPlayer.Player.spotify.changeNotification, object: nil)
        #expect(await until { nowPlaying.track == newer })
        await source.release()
        try? await Task.sleep(for: .milliseconds(30))
        #expect(nowPlaying.track == newer)
    }
}
