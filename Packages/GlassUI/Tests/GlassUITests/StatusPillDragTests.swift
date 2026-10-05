import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct StatusPillDragTests {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 476),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let view = LauncherView()

    init() {
        panel.contentView = view
        view.pills = ["disk", "thermal"].map { id in
            .init(id: id, name: id, symbol: "cpu", value: "1", action: "Open \(id)")
        }
        view.layoutSubtreeIfNeeded()
    }

    @Test func commandDraggingAPillPastAnotherMovesItThereAndSavesTheOrder() throws {
        var saved: [StatusBarLayout] = []
        var ran: [String] = []
        view.onStatusLayout = { saved.append($0) }
        view.onPill = { ran.append($0.id) }
        let disk = try #require(view.statusBar.views.first)
        let thermal = try #require(view.statusBar.views.last)
        let past = thermal.convert(NSPoint(x: thermal.bounds.maxX - 1, y: 1), to: nil)
        disk.mouseDown(with: try mouse(.leftMouseDown, at: past, [.command]))
        disk.mouseDragged(with: try mouse(.leftMouseDragged, at: past, [.command]))
        #expect(view.statusBar.views.map(\.identifier?.rawValue) == ["thermal", "disk"])
        view.pills = ["disk", "thermal"].map { id in
            .init(id: id, name: id, symbol: "cpu", value: id, action: "Open \(id)")
        }
        #expect(view.statusBar.views.map(\.text) == ["thermal", "disk"])
        disk.mouseUp(with: try mouse(.leftMouseUp, at: past, [.command]))
        #expect(view.statusBar.pills.map(\.id) == ["thermal", "disk"])
        #expect(saved.count == 1)
        #expect(ran.isEmpty)
        let first = try #require(view.statusBar.views.first)
        first.mouseDown(with: try mouse(.leftMouseDown, at: past))
        #expect(ran == ["thermal"])
    }

    @Test func commandClickingAPillWithoutMovingItChangesNothing() throws {
        var saved: [StatusBarLayout] = []
        view.onStatusLayout = { saved.append($0) }
        let disk = try #require(view.statusBar.views.first)
        let point = disk.convert(NSPoint(x: 1, y: 1), to: nil)
        disk.mouseDown(with: try mouse(.leftMouseDown, at: point, [.command]))
        disk.mouseUp(with: try mouse(.leftMouseUp, at: point, [.command]))
        #expect(saved.isEmpty)
        #expect(view.selectedPill == nil)
    }

    private func mouse(
        _ type: NSEvent.EventType, at point: NSPoint, _ modifiers: NSEvent.ModifierFlags = []
    ) throws -> NSEvent {
        try #require(
            NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: modifiers, timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1,
                pressure: 1))
    }
}
