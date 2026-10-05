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
        view.statusBar.holdsMouse = { true }
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
        disk.mouseDown(with: try mouse(.leftMouseDown, at: centre(of: disk), [.command]))
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

    @Test func theSelectedPillKeepsItsHighlightWhileItIsDragged() throws {
        view.selectPill(0)
        let disk = try #require(view.statusBar.views.first)
        let past = try drag(disk)
        view.pills = pills(["disk", "thermal"], value: "2")
        let selected = view.statusBar.views.filter(\.selected).map(\.identifier?.rawValue)
        #expect(selected == ["disk"])
        disk.mouseUp(with: try mouse(.leftMouseUp, at: past, [.command]))
    }

    @Test func aPillThatAppearsMidDragKeepsTheReorder() throws {
        var saved: [StatusBarLayout] = []
        view.onStatusLayout = { saved.append($0) }
        let disk = try #require(view.statusBar.views.first)
        let past = try drag(disk)
        view.pills = pills(["disk", "thermal", "vpn"], value: "1")
        #expect(view.statusBar.views.map(\.identifier?.rawValue) == ["thermal", "disk"])
        disk.mouseUp(with: try mouse(.leftMouseUp, at: past, [.command]))
        #expect(saved.count == 1)
        #expect(view.statusBar.pills.map(\.id) == ["thermal", "vpn", "disk"])
        #expect(view.statusBar.views.map(\.identifier?.rawValue) == ["thermal", "vpn", "disk"])
    }

    @Test func aPillThatAppearsBeforeTheFirstMoveKeepsTheDraggedPill() throws {
        var saved: [StatusBarLayout] = []
        view.onStatusLayout = { saved.append($0) }
        let disk = try #require(view.statusBar.views.first)
        let thermal = try #require(view.statusBar.views.last)
        let past = thermal.convert(NSPoint(x: thermal.bounds.maxX - 1, y: 1), to: nil)
        disk.mouseDown(with: try mouse(.leftMouseDown, at: centre(of: disk), [.command]))
        view.pills = pills(["disk", "thermal", "vpn"], value: "1")
        #expect(view.statusBar.views.contains { $0 === disk })
        disk.mouseDragged(with: try mouse(.leftMouseDragged, at: past, [.command]))
        disk.mouseUp(with: try mouse(.leftMouseUp, at: past, [.command]))
        #expect(saved.count == 1)
        #expect(view.statusBar.pills.map(\.id) == ["thermal", "vpn", "disk"])
    }

    @Test func aPlainPressAfterALostCommandPressDoesNotReorder() throws {
        var ran: [String] = []
        view.onPill = { ran.append($0.id) }
        let disk = try #require(view.statusBar.views.first)
        let thermal = try #require(view.statusBar.views.last)
        let past = thermal.convert(NSPoint(x: thermal.bounds.maxX - 1, y: 1), to: nil)
        disk.mouseDown(with: try mouse(.leftMouseDown, at: centre(of: disk), [.command]))
        disk.mouseDown(with: try mouse(.leftMouseDown, at: centre(of: disk)))
        disk.mouseDragged(with: try mouse(.leftMouseDragged, at: past))
        #expect(ran == ["disk"])
        #expect(view.statusBar.views.map(\.identifier?.rawValue) == ["disk", "thermal"])
    }

    @Test func aNewCommandDragAfterALostOneStartsFromTheSavedOrder() throws {
        var saved: [StatusBarLayout] = []
        view.onStatusLayout = { saved.append($0) }
        view.pills = pills(["disk", "thermal", "vpn"], value: "1")
        view.layoutSubtreeIfNeeded()
        let disk = try #require(view.statusBar.views.first)
        let vpn = try #require(view.statusBar.views.last)
        let end = vpn.convert(NSPoint(x: vpn.bounds.maxX - 1, y: 1), to: nil)
        disk.mouseDown(with: try mouse(.leftMouseDown, at: centre(of: disk), [.command]))
        disk.mouseDragged(with: try mouse(.leftMouseDragged, at: end, [.command]))
        #expect(view.statusBar.views.map(\.identifier?.rawValue) == ["thermal", "vpn", "disk"])
        vpn.mouseDown(with: try mouse(.leftMouseDown, at: centre(of: vpn), [.command]))
        let front = try #require(view.statusBar.views.first)
        let start = front.convert(NSPoint(x: 1, y: 1), to: nil)
        vpn.mouseDragged(with: try mouse(.leftMouseDragged, at: start, [.command]))
        vpn.mouseUp(with: try mouse(.leftMouseUp, at: start, [.command]))
        #expect(saved.count == 1)
        #expect(view.statusBar.pills.map(\.id) == ["vpn", "disk", "thermal"])
        #expect(view.statusBar.views.map(\.identifier?.rawValue) == ["vpn", "disk", "thermal"])
    }

    @Test func aDragWhoseMouseUpNeverCameStopsHoldingTheBar() throws {
        let disk = try #require(view.statusBar.views.first)
        _ = try drag(disk)
        view.statusBar.holdsMouse = { false }
        view.pills = pills(["disk", "thermal"], value: "2")
        #expect(view.statusBar.views.map(\.identifier?.rawValue) == ["disk", "thermal"])
        view.pills = pills(["disk", "thermal", "vpn"], value: "2")
        #expect(view.statusBar.views.map(\.identifier?.rawValue) == ["disk", "thermal", "vpn"])
    }

    private func drag(_ pill: StatusPill) throws -> NSPoint {
        let thermal = try #require(view.statusBar.views.last)
        let past = thermal.convert(NSPoint(x: thermal.bounds.maxX - 1, y: 1), to: nil)
        pill.mouseDown(with: try mouse(.leftMouseDown, at: centre(of: pill), [.command]))
        pill.mouseDragged(with: try mouse(.leftMouseDragged, at: past, [.command]))
        return past
    }

    private func pills(_ ids: [String], value: String) -> [StatusBar.Pill] {
        ids.map { id in .init(id: id, name: id, symbol: "cpu", value: value, action: "Open \(id)") }
    }

    private func centre(of pill: StatusPill) -> NSPoint {
        pill.convert(NSPoint(x: pill.bounds.midX, y: pill.bounds.midY), to: nil)
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
