import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetFloatTests {
    private static let frame = NSRect(x: 100, y: 100, width: 760, height: 476)
    private static let width = (760 - 5 * 10) / 6.0

    private let panel = NSPanel(
        contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
        defer: false)
    private let view = LauncherView()

    init() {
        panel.contentView = view
        view.results.sections = [.init(title: "Commands", items: [item("Safari")])]
        view.widgets = (1...7).map(numbered)
        view.onQuery = { [view] _ in view.show(view.results.sections) }
        panel.makeFirstResponder(view.field)
    }

    @Test func aboveFloatsSixToARowFlushWithThePanelSixteenPointsOverIt() throws {
        arrange(.above)
        view.layoutSubtreeIfNeeded()
        let floats = view.widgetGrid.floats
        #expect(floats.count == 7)
        #expect(floats.allSatisfy { $0.parent === panel })
        #expect(view.widgetGrid.frame.height == 0)
        expect(floats[0].frame, NSRect(x: 100, y: 680, width: Self.width, height: 78))
        #expect(abs(floats[5].frame.maxX - 860) < 0.5)
        expect(floats[6].frame, NSRect(x: 100, y: 592, width: Self.width, height: 78))
        #expect(view.widgetOverhang == 182)
        #expect(try #require(floats.first).glass.contentView === view.widgetGrid.tiles.first)
    }

    @Test func aboveGivesTheTrackTwoColumnsLikeTheInlineGrid() {
        let track = WidgetGrid.Track(title: "Song", artist: "Band", artwork: nil, isPlaying: true)
        view.widgets =
            [.init(id: "music", name: "Now Playing", track: track, action: "Play", spoken: "Song")]
            + (1...5).map(numbered)
        arrange(.above)
        let floats = view.widgetGrid.floats
        expect(floats[0].frame, NSRect(x: 100, y: 680, width: 2 * Self.width + 10, height: 78))
        expect(
            floats[1].frame,
            NSRect(x: 100 + 2 * (Self.width + 10), y: 680, width: Self.width, height: 78))
        expect(floats[5].frame, NSRect(x: 100, y: 592, width: Self.width, height: 78))
        #expect(view.widgetOverhang == 182)
    }

    @Test func aroundStacksAColumnOnEachSideFromThePanelTop() {
        arrange(.around)
        let floats = view.widgetGrid.floats
        expect(floats[0].frame, NSRect(x: -140, y: 498, width: 220, height: 78))
        expect(floats[3].frame, NSRect(x: -140, y: 234, width: 220, height: 78))
        expect(floats[4].frame, NSRect(x: 880, y: 498, width: 220, height: 78))
        expect(floats[6].frame, NSRect(x: 880, y: 322, width: 220, height: 78))
        #expect(view.widgetOverhang == 0)
    }

    @Test func theArrowsGoToTheNearestTileThatWayAcrossThePanel() {
        var ran: [String] = []
        view.onWidget = { ran.append($0.id) }
        arrange(.around)
        press(kVK_UpArrow, "\u{F700}")
        #expect(view.selectedWidget == 0)
        #expect(view.widgetGrid.tiles.map(\.selected) == [true] + Array(repeating: false, count: 6))
        press(kVK_RightArrow, "\u{F703}")
        #expect(view.selectedWidget == 4)
        press(kVK_RightArrow, "\u{F703}")
        #expect(view.selectedWidget == 4)
        press(kVK_DownArrow, "\u{F701}")
        press(kVK_DownArrow, "\u{F701}")
        #expect(view.selectedWidget == 6)
        #expect(view.actionLabel.stringValue == "Open 7")
        press(kVK_LeftArrow, "\u{F702}")
        #expect(view.selectedWidget == 2)
        press(kVK_Return, "\r")
        #expect(ran == ["3"])
        press(kVK_DownArrow, "\u{F701}")
        #expect(view.selectedWidget == 3)
        press(kVK_DownArrow, "\u{F701}")
        #expect(view.selectedWidget == nil)
        #expect(view.results.selectedItem?.id == "Safari")
        press(kVK_UpArrow, "\u{F700}")
        press(kVK_Escape, "\u{1B}")
        #expect(view.selectedWidget == nil)
        #expect(!view.results.hidesSelection)
    }

    @Test func typingTakesTheFloatsAwayAndClearingBringsThemBack() {
        arrange(.above)
        press(kVK_ANSI_A, "a")
        #expect(view.widgetGrid.floats.allSatisfy { $0.parent == nil })
        view.replaceQuery(with: "")
        #expect(view.widgetGrid.floats.allSatisfy { $0.parent === panel })
    }

    @Test func resizingThePanelKeepsTheFloatsOnItsTop() {
        arrange(.above)
        panel.setFrame(NSRect(x: 100, y: 64, width: 760, height: 548), display: false)
        view.layoutSubtreeIfNeeded()
        expect(
            view.widgetGrid.floats[6].frame,
            NSRect(x: 100, y: 612 + 16, width: Self.width, height: 78))
    }

    @Test func goingBackInlinePutsTheTilesInThePanel() {
        arrange(.above)
        let floats = view.widgetGrid.floats
        arrange(.inPanel)
        #expect(view.widgetGrid.floats.isEmpty)
        #expect(floats.allSatisfy { $0.parent == nil })
        #expect(view.widgetGrid.tiles.allSatisfy { unsafe $0.superview === view.widgetGrid })
        #expect(view.widgetOverhang == 0)
    }

    @Test func clickingAFloatingTileSelectsAndRunsIt() throws {
        var ran: [String] = []
        view.onWidget = { ran.append($0.id) }
        arrange(.above)
        #expect(try #require(view.widgetGrid.tiles.last).accessibilityPerformPress())
        #expect(view.selectedWidget == 6)
        #expect(view.widgetGrid.tiles.last?.selected == true)
        #expect(ran == ["7"])
    }

    private func expect(
        _ actual: NSRect, _ expected: NSRect, sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let close = [
            (actual.minX, expected.minX), (actual.minY, expected.minY),
            (actual.width, expected.width), (actual.height, expected.height),
        ].allSatisfy { abs($0 - $1) < 1 }
        #expect(close, "\(actual) is not \(expected)", sourceLocation: sourceLocation)
    }

    private func numbered(_ number: Int) -> WidgetGrid.Widget {
        .init(
            id: "\(number)", name: "Widget \(number)", value: "\(number)", detail: "",
            action: "Open \(number)",
            spoken: "Widget \(number)")
    }

    private func press(_ keyCode: Int, _ characters: String) {
        guard
            let event = NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, characters: characters,
                charactersIgnoringModifiers: characters, isARepeat: false,
                keyCode: UInt16(keyCode))
        else {
            Issue.record("Could not make a key event for \(keyCode)")
            return
        }
        panel.sendEvent(event)
    }

    private func item(_ title: String) -> ResultList.Item {
        .init(
            id: title, title: title, subtitle: "", kind: "Command", symbol: "star",
            action: "Run Command")
    }

    private func arrange(_ arrangement: WidgetSettings.Arrangement) {
        view.widgetSpots = WidgetSettings().spots(arrangement, from: view.widgets.map(\.id))
    }
}
