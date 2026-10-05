import Foundation
import Testing

@testable import AppCore

@Suite struct LyricsPresenceTests {
    private final class Screen {
        private var presence: LyricsPresence

        init(hideAfter: TimeInterval?) {
            presence = LyricsPresence(hideAfter: hideAfter)
        }

        func shows(timed: Bool, playing: Bool, at now: TimeInterval) -> Bool {
            presence.shows(timed: timed, playing: playing, at: now)
        }
    }

    @Test func aPlayingSongWithTimedLyricsIsShown() {
        let presence = Screen(hideAfter: 10)
        #expect(presence.shows(timed: true, playing: true, at: 0))
    }

    @Test func aSongWithoutTimedLyricsIsNeverShown() {
        let presence = Screen(hideAfter: 10)
        #expect(!presence.shows(timed: false, playing: true, at: 0))
        #expect(!presence.shows(timed: false, playing: false, at: 1))
    }

    @Test func aPausedSongStaysUntilTheGraceEnds() {
        let presence = Screen(hideAfter: 10)
        #expect(presence.shows(timed: true, playing: true, at: 0))
        #expect(presence.shows(timed: true, playing: false, at: 1))
        #expect(presence.shows(timed: true, playing: false, at: 10.9))
        #expect(!presence.shows(timed: true, playing: false, at: 11))
        #expect(!presence.shows(timed: true, playing: false, at: 60))
    }

    @Test func playingAgainBringsItBackAndRestartsTheGrace() {
        let presence = Screen(hideAfter: 10)
        _ = presence.shows(timed: true, playing: false, at: 0)
        #expect(!presence.shows(timed: true, playing: false, at: 20))
        #expect(presence.shows(timed: true, playing: true, at: 21))
        #expect(presence.shows(timed: true, playing: false, at: 25))
        #expect(presence.shows(timed: true, playing: false, at: 34.9))
        #expect(!presence.shows(timed: true, playing: false, at: 35))
    }

    @Test func aZeroGraceHidesAtTheMomentOfThePause() {
        let presence = Screen(hideAfter: 0)
        #expect(presence.shows(timed: true, playing: true, at: 0))
        #expect(!presence.shows(timed: true, playing: false, at: 1))
    }

    @Test func neverHidingKeepsAPausedSongOnScreen() {
        let presence = Screen(hideAfter: nil)
        #expect(presence.shows(timed: true, playing: false, at: 0))
        #expect(presence.shows(timed: true, playing: false, at: 100_000))
    }

    @Test func theGraceCountsFromThePauseEvenWhileNothingWasTimed() {
        let presence = Screen(hideAfter: 10)
        #expect(!presence.shows(timed: false, playing: false, at: 0))
        #expect(!presence.shows(timed: true, playing: false, at: 12))
    }
}
