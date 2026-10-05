import AppKit
import Testing

@testable import GlassUI

@MainActor
struct WidgetPointerRig {
    typealias Kind = NSEvent.EventType
    typealias Flags = NSEvent.ModifierFlags

    private static let frame = (x: 100.0, y: 100.0, width: 760.0, height: 548.0)
    private static let corner = (x: 5.0, y: 5.0)

    let panel = NSPanel(
        contentRect: NSRect(
            x: frame.x, y: frame.y, width: frame.width, height: frame.height),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    let view = LauncherView()
    let widgets = ["clock", "weather", "battery"].map { id in
        WidgetGrid.Widget(
            id: id, name: id.capitalized, value: id, detail: "", action: "Open \(id.capitalized)",
            spoken: id.capitalized)
    }

    var tiles: [WidgetTile] { view.widgetGrid.tiles }
    var titles: [String] { view.widgetMenu?.rows.map(\.label.stringValue) ?? [] }

    init() {
        panel.contentView = view
        view.results.sections = [
            .init(
                title: "Commands",
                items: [
                    .init(
                        id: "Safari", title: "Safari", subtitle: "", kind: "Command",
                        symbol: "star", action: "Run Command")
                ])
        ]
        view.widgets = widgets
        view.widgetCatalogue = widgets.map { widget in
            .init(id: widget.id, name: widget.name, summary: "", group: .today)
        }
        panel.makeFirstResponder(view.field)
        view.layoutSubtreeIfNeeded()
    }

    func open(_ index: Int) throws {
        view.closeWidgetMenu()
        tiles[index].rightMouseDown(with: try event(.rightMouseDown, on: tiles[index]))
        view.layoutSubtreeIfNeeded()
        #expect(view.widgetMenu != nil)
    }

    func event(_ type: Kind, on tile: WidgetTile) throws -> NSEvent {
        try event(type, on: tile, at: centre(of: tile), flags: [], count: 1)
    }

    func event(_ type: Kind, on tile: WidgetTile, at point: NSPoint) throws -> NSEvent {
        try event(type, on: tile, at: point, flags: [], count: 1)
    }

    func event(_ type: Kind, on tile: WidgetTile, flags: Flags) throws -> NSEvent {
        try event(type, on: tile, at: centre(of: tile), flags: flags, count: 1)
    }

    func event(_ type: Kind, on tile: WidgetTile, count: Int) throws -> NSEvent {
        try event(type, on: tile, at: centre(of: tile), flags: [], count: count)
    }

    func centre(of tile: WidgetTile) -> NSPoint {
        NSPoint(x: tile.bounds.midX, y: tile.bounds.midY)
    }

    private func event(
        _ type: Kind, on tile: WidgetTile, at point: NSPoint, flags: Flags, count: Int
    ) throws -> NSEvent {
        try #require(
            NSEvent.mouseEvent(
                with: type, location: tile.convert(point, to: nil), modifierFlags: flags,
                timestamp: 0, windowNumber: unsafe tile.window?.windowNumber ?? 0, context: nil,
                eventNumber: 0, clickCount: count, pressure: 1))
    }

    func crossing(_ type: Kind, _ tile: WidgetTile) throws -> NSEvent {
        try #require(
            unsafe NSEvent.enterExitEvent(
                with: type,
                location: tile.convert(NSPoint(x: Self.corner.x, y: Self.corner.y), to: nil),
                modifierFlags: [], timestamp: 0,
                windowNumber: unsafe tile.window?.windowNumber ?? 0, context: nil, eventNumber: 0,
                trackingNumber: 0, userData: nil))
    }

    func mouse(_ type: Kind, at point: NSPoint) throws -> NSEvent {
        try #require(
            NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1,
                pressure: 1))
    }
}
