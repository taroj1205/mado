import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetPlayerPressTests {
    private let rig = WidgetPointerRig()

    private var view: LauncherView { rig.view }

    private func showPlayer() -> WidgetTile {
        let track = WidgetGrid.Track(title: "Song", artist: "Band", artwork: nil, isPlaying: true)
        view.widgets[1] = .init(
            id: "music", name: "Now Playing", track: track, action: "Play", spoken: "Song")
        view.layoutSubtreeIfNeeded()
        return rig.tiles[1]
    }

    @Test func aClickOnThePlayerRunsItsActionWhenTheButtonComesUp() throws {
        var ran: [String] = []
        view.onWidget = { ran.append($0.id) }
        let tile = showPlayer()
        tile.holdDelay.duration = .seconds(5)
        tile.mouseDown(with: try rig.event(.leftMouseDown, on: tile))
        #expect(ran.isEmpty)
        #expect(view.selectedWidget == 1)
        tile.mouseUp(with: try rig.event(.leftMouseUp, on: tile))
        #expect(ran == ["music"])
    }

    @Test func holdingThePlayerIntoEditModeDoesNotRunItsAction() async throws {
        var ran: [String] = []
        view.onWidget = { ran.append($0.id) }
        var picked = 0
        view.widgetGrid.beginsDrag = { _, _, _ in picked += 1 }
        let tile = showPlayer()
        tile.holdDelay.duration = .milliseconds(20)
        tile.mouseDown(with: try rig.event(.leftMouseDown, on: tile))
        for _ in 0..<100 where !view.editingWidgets {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(view.editingWidgets)
        #expect(picked == 1)
        let held = try #require(view.widgetGrid.tiles.first { $0.widgetID == "music" })
        held.mouseUp(with: try rig.event(.leftMouseUp, on: held))
        #expect(ran.isEmpty)
    }

    @Test func draggingThePlayerDoesNotRunItsActionEither() throws {
        var ran: [String] = []
        view.onWidget = { ran.append($0.id) }
        var dragged = 0
        view.widgetGrid.beginsDrag = { _, _, _ in dragged += 1 }
        let tile = showPlayer()
        tile.holdDelay.duration = .seconds(5)
        tile.mouseDown(with: try rig.event(.leftMouseDown, on: tile))
        tile.mouseDragged(
            with: try rig.event(.leftMouseDragged, on: tile, at: NSPoint(x: 40, y: 40)))
        tile.mouseUp(with: try rig.event(.leftMouseUp, on: tile))
        #expect(ran.isEmpty)
        #expect(dragged == 0)
    }

    @Test func specialisedClicksOnAWidgetCloseItsOpenMenu() throws {
        let grid = view.widgetGrid
        let clicks: [() -> Void] = [
            { grid.onSkip?(1, .next) }, { grid.onPage?(1, .next) },
            { grid.onSeek?(1, 0) }, { grid.onDay?("on 5 Oct") },
        ]
        for click in clicks {
            try rig.open(1)
            click()
            #expect(view.widgetMenu == nil)
        }
    }
}
