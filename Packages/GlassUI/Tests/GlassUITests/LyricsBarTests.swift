import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite(.silentWindows, .enabled(if: !NSScreen.screens.isEmpty, "Placing lyrics needs a screen"))
struct LyricsBarTests {
    private static let spot = NSRect(x: 628, y: 1_139, width: 146, height: 22)
    private let bar = LyricsBar()

    @Test func itSitsInTheSpotAboveTheMenuBarWithoutTakingFocusOrClicks() {
        bar.show(LyricsFloatRig.synced, in: Self.spot, hidesInSharing: true)
        defer { bar.hide(animated: false) }
        #expect(bar.isShown)
        #expect(bar.panel.isVisible)
        #expect(bar.frame == Self.spot)
        #expect(bar.panel.level == .statusBar)
        #expect(!bar.panel.canBecomeKey)
        #expect(bar.panel.ignoresMouseEvents)
        #expect(bar.panel.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(bar.line.accessibilityValue() as? String == LyricsFloatRig.lines[1])
    }

    @Test func itFollowsTheSpotAndNamesItsWindowForTheStatusItemScan() throws {
        bar.show(LyricsFloatRig.synced, in: Self.spot, hidesInSharing: true)
        defer { bar.hide(animated: false) }
        let moved = Self.spot.offsetBy(dx: 40, dy: 0)
        bar.show(LyricsFloatRig.synced, in: moved, hidesInSharing: true)
        #expect(bar.frame == moved)
        #expect(try #require(bar.windowNumber) > 0)
    }

    @Test func sharingFollowsTheSetting() {
        bar.show(LyricsFloatRig.synced, in: Self.spot, hidesInSharing: false)
        defer { bar.hide(animated: false) }
        #expect(bar.panel.sharingType == .readOnly)
        bar.show(LyricsFloatRig.synced, in: Self.spot, hidesInSharing: true)
        #expect(bar.panel.sharingType == .none)
    }

    @Test func hidingClosesTheWindow() {
        bar.show(LyricsFloatRig.synced, in: Self.spot, hidesInSharing: true)
        bar.hide(animated: false)
        #expect(!bar.isShown)
        #expect(!bar.panel.isVisible)
        bar.hide(animated: false)
        #expect(!bar.isShown)
    }

    @Test func showingAgainAfterAFadeBringsItBack() async throws {
        bar.show(LyricsFloatRig.synced, in: Self.spot, hidesInSharing: true)
        defer { bar.hide(animated: false) }
        bar.hide(animated: true)
        bar.show(LyricsFloatRig.synced, in: Self.spot, hidesInSharing: true)
        try await Task.sleep(for: .seconds(LyricsBar.fadeSeconds * 2))
        #expect(bar.isShown)
        #expect(bar.panel.isVisible)
    }
}
