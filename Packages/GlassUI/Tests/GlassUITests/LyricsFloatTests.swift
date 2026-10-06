import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite(.silentWindows, .enabled(if: !NSScreen.screens.isEmpty, "Placing lyrics needs a screen"))
struct LyricsFloatTests {
    static let restoresSharing: Bool = {
        let probe = NSPanel()
        probe.orderFront(nil)
        probe.sharingType = .none
        probe.sharingType = .readOnly
        defer { probe.orderOut(nil) }
        return probe.sharingType == .readOnly
    }()

    private let rig = LyricsFloatRig()

    private var float: LyricsFloat {
        rig.float
    }

    @Test func theIslandHangsUnderTheMenuBarWithoutTakingFocus() throws {
        let screen = try #require(rig.screen)
        rig.show(.island)
        defer { float.hide(animated: false) }
        #expect(float.isShown)
        #expect(float.panel.isVisible)
        #expect(float.frame == LyricsGeometry.island(LyricsLook.line.size, in: screen.visibleFrame))
        #expect(!float.panel.canBecomeKey)
        #expect(!float.panel.canBecomeMain)
        #expect(float.panel.styleMask.contains(.nonactivatingPanel))
        #expect(float.panel.level == .statusBar)
        #expect(float.panel.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(float.panel.collectionBehavior.contains(.fullScreenAuxiliary))
        #expect(float.panel.ignoresMouseEvents)
    }

    @Test func screenSharingDoesNotSeeItWhenHidden() {
        rig.show(.island)
        defer { float.hide(animated: false) }
        #expect(float.panel.sharingType == NSWindow.SharingType.none)
    }

    @Test func screenSharingSeesItAgainWhenAllowed() throws {
        if !Self.restoresSharing {
            try Test.cancel("This host ignores sharing changes on shown windows")
        }
        rig.show(.island)
        defer { float.hide(animated: false) }
        rig.hidesInSharing = false
        rig.show(.island)
        #expect(float.panel.sharingType == .readOnly)
    }

    @Test func everyLookTakesItsSizeInEveryCorner() throws {
        let screen = try #require(rig.screen)
        defer { float.hide(animated: false) }
        for look in LyricsLook.allCases {
            for corner in LyricsCorner.allCases {
                rig.look = look
                rig.show(.corner(corner))
                #expect(
                    float.frame
                        == LyricsGeometry.corner(corner, size: look.size, in: screen.visibleFrame))
                #expect(float.card.look == look)
            }
        }
    }

    @Test func hidingAndShowingAgainBringsTheWindowBack() {
        rig.show(.island)
        float.hide(animated: false)
        #expect(!float.isShown)
        #expect(!float.panel.isVisible)
        rig.show(.island)
        defer { float.hide(animated: false) }
        #expect(float.isShown)
        #expect(float.panel.isVisible)
    }

    @Test func aFadeOutEndsHidden() async throws {
        rig.show(.island)
        float.hide(animated: true)
        #expect(!float.isShown)
        for _ in 0..<100 where float.panel.isVisible {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!float.panel.isVisible)
    }

    @Test func showingDuringAFadeOutKeepsItUp() async throws {
        rig.show(.island)
        float.hide(animated: true)
        rig.show(.island)
        defer { float.hide(animated: false) }
        try await Task.sleep(for: .milliseconds(400))
        #expect(float.isShown)
        #expect(float.panel.isVisible)
    }

    @Test func theControlsReportWhatWasPressed() {
        rig.look = .card
        rig.show(.corner(.topLeading))
        defer { float.hide(animated: false) }
        for button in rig.card.controls {
            #expect(!button.isHidden)
            #expect(button.acceptsFirstMouse(for: nil))
            button.performClick(nil)
        }
        #expect(rig.controls == [.previous, .playPause, .next])
        #expect(rig.card.previous.accessibilityLabel() == "Previous track")
        #expect(rig.card.next.accessibilityLabel() == "Next track")
    }

    @Test func playPauseSaysWhatItWillDo() {
        rig.look = .card
        rig.show(.island)
        defer { float.hide(animated: false) }
        #expect(rig.card.playPause.accessibilityLabel() == "Pause")
        rig.verse = LyricsFloatRig.song(.synced, current: 1, playing: false)
        rig.show(.island)
        #expect(rig.card.playPause.accessibilityLabel() == "Play")
    }

    @Test func itIsOneLyricsGroupWhoseValueIsTheSungLine() {
        rig.show(.island)
        defer { float.hide(animated: false) }
        #expect(rig.card.isAccessibilityElement())
        #expect(rig.card.accessibilityRole() == .group)
        #expect(rig.card.accessibilityLabel() == "Lyrics")
        #expect(rig.card.accessibilityValue() as? String == LyricsFloatRig.lines[1])
        rig.verse = LyricsFloatRig.song(.synced, current: 3, playing: true)
        rig.show(.island)
        #expect(rig.card.accessibilityValue() as? String == LyricsFloatRig.lines[3])
    }

    @Test(arguments: [
        WidgetGrid.LyricsStatus.plain, .instrumental, .missing, .loading, .off,
    ])
    func withoutTimedLinesOnlyTheSongShows(status: WidgetGrid.LyricsStatus) {
        defer { float.hide(animated: false) }
        rig.verse = LyricsFloatRig.song(status, current: 1, playing: true)
        for look in LyricsLook.allCases {
            rig.look = look
            rig.show(.island)
            #expect(rig.card.text?.line == nil)
            #expect(rig.card.lyric.isHidden)
            #expect(rig.card.following.isHidden)
            #expect(rig.card.column.isHidden)
            #expect(rig.card.title.stringValue == "Low Tide")
            #expect(rig.card.accessibilityValue() as? String == "Low Tide · Harbour Lights")
        }
        rig.look = .line
        rig.show(.island)
        #expect(!rig.card.line.isHidden)
    }

    @Test func timedLinesFillEachLook() {
        defer { float.hide(animated: false) }
        rig.show(.island)
        #expect(!rig.card.line.isHidden)
        #expect(rig.card.cover.isHidden)
        rig.look = .card
        rig.show(.island)
        #expect(rig.card.line.isHidden)
        #expect(!rig.card.lyric.isHidden)
        #expect(rig.card.following.stringValue == LyricsFloatText.gap)
        rig.look = .lyrics
        rig.show(.island)
        #expect(!rig.card.column.isHidden)
        #expect(rig.card.lyric.isHidden)
    }

    @Test func aGapBetweenLinesShowsDots() {
        rig.look = .card
        rig.verse = LyricsFloatRig.song(.synced, current: 2, playing: true)
        rig.show(.island)
        defer { float.hide(animated: false) }
        #expect(rig.card.text?.line == LyricsFloatText.gap)
        #expect(rig.card.following.stringValue == LyricsFloatRig.lines[3])
        #expect(rig.card.accessibilityValue() as? String == LyricsFloatText.breakLabel)
    }

    @Test func desktopTypeSitsUnderEveryWindow() throws {
        let screen = try #require(rig.screen)
        rig.show(.desktop)
        defer { float.hide(animated: false) }
        let panel = float.desktopPanel
        #expect(panel.isVisible)
        #expect(!float.panel.isVisible)
        #expect(panel.level.rawValue == Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        #expect(panel.level.rawValue < Int(CGWindowLevelForKey(.desktopIconWindow)))
        #expect(panel.ignoresMouseEvents)
        #expect(!panel.canBecomeKey)
        #expect(panel.collectionBehavior.contains(.stationary))
        #expect(panel.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(float.frame.minX == screen.visibleFrame.minX + 26)
        #expect(float.frame.minY == screen.visibleFrame.minY + 22)
        #expect(float.desktop.previous.stringValue == LyricsFloatRig.lines[0])
        #expect(float.desktop.next.stringValue == LyricsFloatText.gap)
        #expect(float.desktop.accessibilityValue() as? String == LyricsFloatRig.lines[1])
    }

    @Test func movingOffTheDesktopSwapsWindows() {
        rig.show(.desktop)
        rig.show(.island)
        defer { float.hide(animated: false) }
        #expect(!float.desktopPanel.isVisible)
        #expect(float.panel.isVisible)
    }
}
