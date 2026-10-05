import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetHoverTests {
    private let rig = WidgetPointerRig()

    private var view: LauncherView { rig.view }
    private var tiles: [WidgetTile] { rig.tiles }

    @Test func theButtonAppearsAfterThePointerRestsOnAWidget() async throws {
        let tile = tiles[1]
        #expect(tile.hoverDelay.duration == .seconds(0.3))
        tile.hoverDelay.duration = .milliseconds(20)
        #expect(tile.more.isHidden)
        tile.mouseEntered(with: try rig.crossing(.mouseEntered, tile))
        #expect(tile.more.isHidden)
        for _ in 0..<100 where tile.more.isHidden {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!tile.more.isHidden)
        tile.layoutSubtreeIfNeeded()
        let frame = tile.moreFrame
        #expect(frame.maxX == tile.bounds.maxX - 6 && frame.maxY == tile.bounds.maxY - 6)
        #expect(frame.size == NSSize(width: 22, height: 22))
        tile.mouseExited(with: try rig.crossing(.mouseExited, tile))
        #expect(tile.more.isHidden)
    }

    @Test func leavingBeforeTheDelayNeverShowsTheButton() async throws {
        let tile = tiles[1]
        tile.hoverDelay.duration = .milliseconds(40)
        tile.mouseEntered(with: try rig.crossing(.mouseEntered, tile))
        tile.mouseExited(with: try rig.crossing(.mouseExited, tile))
        try await Task.sleep(for: .milliseconds(120))
        #expect(tile.more.isHidden)
    }

    @Test func pressingTheButtonOpensTheMenuUnderIt() throws {
        let tile = tiles[1]
        tile.hovering = true
        tile.layoutSubtreeIfNeeded()
        let button = NSPoint(x: tile.moreFrame.midX, y: tile.moreFrame.midY)
        tile.mouseDown(with: try rig.event(.leftMouseDown, on: tile, at: button))
        view.layoutSubtreeIfNeeded()
        let menu = try #require(view.widgetMenu).glass.frame
        let anchor = view.convert(tile.convert(tile.moreFrame, to: nil), from: nil)
        #expect(abs(menu.maxY - (anchor.minY - 5)) < 1)
        #expect(abs(menu.minX - (anchor.minX - 16)) < 1)
        tile.hovering = false
        #expect(!tile.more.isHidden)
        view.closeWidgetMenu()
        #expect(tile.more.isHidden)
    }

    @Test func theButtonStepsLeftOfTheMonthControls() {
        let plain = tiles[1].moreFrame
        let calendar = tiles[0]
        calendar.month.isHidden = false
        calendar.month.isInteractive = true
        #expect(calendar.moreFrame.maxX <= calendar.bounds.maxX - calendar.month.controlStrip - 12)
        #expect(calendar.moreFrame.maxX < plain.maxX)
    }

    @Test func holdingATileHalfASecondOpensEditModeWithItPickedUp() async throws {
        var picked: [(id: String, grab: NSPoint)] = []
        view.widgetGrid.beginsDrag = { tile, _, grab in picked.append((tile.widgetID, grab)) }
        let tile = tiles[1]
        #expect(tile.holdDelay.duration == .seconds(0.5))
        tile.holdDelay.duration = .milliseconds(20)
        let press = try rig.event(.leftMouseDown, on: tile)
        let grab = tile.convert(press.locationInWindow, from: nil)
        tile.mouseDown(with: press)
        #expect(!view.editingWidgets)
        for _ in 0..<100 where !view.editingWidgets {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(view.editingWidgets)
        #expect(view.selectedWidget == 1)
        #expect(picked.map(\.id) == ["weather"])
        #expect(picked.first?.grab == grab)
        #expect(!tiles.map(\.editing).contains(false))
    }

    @Test func releasingMovingOrOpeningCancelsTheHold() async throws {
        var picked = 0
        view.widgetGrid.beginsDrag = { _, _, _ in picked += 1 }
        let tile = tiles[1]
        tile.holdDelay.duration = .milliseconds(40)
        tile.mouseDown(with: try rig.event(.leftMouseDown, on: tile))
        tile.mouseUp(with: try rig.event(.leftMouseUp, on: tile))
        tile.mouseDown(with: try rig.event(.leftMouseDown, on: tile))
        let far = try rig.event(.leftMouseDragged, on: tile, at: NSPoint(x: 40, y: 40))
        tile.mouseDragged(with: far)
        tile.mouseDown(with: try rig.event(.leftMouseDown, on: tile, count: 2))
        tile.mouseUp(with: try rig.event(.leftMouseUp, on: tile))
        view.opensWidgetsOnSingleClick = true
        tile.mouseDown(with: try rig.event(.leftMouseDown, on: tile))
        try await Task.sleep(for: .milliseconds(150))
        #expect(!view.editingWidgets)
        #expect(picked == 0)
    }

    @Test func aSteadyPressSurvivesALittleJitter() async throws {
        var picked = 0
        view.widgetGrid.beginsDrag = { _, _, _ in picked += 1 }
        let tile = tiles[1]
        tile.holdDelay.duration = .milliseconds(30)
        tile.mouseDown(with: try rig.event(.leftMouseDown, on: tile))
        tile.mouseDragged(
            with: try rig.event(
                .leftMouseDragged, on: tile,
                at: NSPoint(x: tile.bounds.midX + 2, y: tile.bounds.midY)))
        for _ in 0..<100 where !view.editingWidgets {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(view.editingWidgets)
    }
}
