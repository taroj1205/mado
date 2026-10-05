import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite(.silentWindows) struct AreaSelectorTests {
    private static let frame = CGRect(x: 100, y: 50, width: 400, height: 300)

    private static func mouse(_ type: NSEvent.EventType, at point: CGPoint) throws -> NSEvent {
        try #require(
            NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: 0, windowNumber: 0,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
    }

    private static func key(_ code: Int) throws -> NSEvent {
        try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
                context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false,
                keyCode: UInt16(code)))
    }

    private static func drag(
        _ panel: AreaPanel, from start: CGPoint, to end: CGPoint
    ) throws {
        panel.area.mouseDown(with: try mouse(.leftMouseDown, at: start))
        panel.area.mouseDragged(with: try mouse(.leftMouseDragged, at: end))
        panel.area.mouseUp(with: try mouse(.leftMouseUp, at: end))
    }

    @Test func draggingReportsTheAreaInScreenCoordinates() throws {
        let panel = AreaPanel(frame: Self.frame)
        var areas: [CGRect] = []
        panel.onSelect = { areas.append($0) }

        try Self.drag(panel, from: CGPoint(x: 40, y: 30), to: CGPoint(x: 240, y: 130))

        #expect(areas == [CGRect(x: 140, y: 80, width: 200, height: 100)])
        #expect(panel.area.selection == nil)
    }

    @Test func aClickWithoutDraggingSelectsNothing() throws {
        let panel = AreaPanel(frame: Self.frame)
        var areas: [CGRect] = []
        panel.onSelect = { areas.append($0) }

        try Self.drag(panel, from: CGPoint(x: 40, y: 30), to: CGPoint(x: 42, y: 31))

        #expect(areas.isEmpty)
        #expect(panel.area.selection == nil)
    }

    @Test func theSelectionFollowsTheDragUntilTheButtonIsReleased() throws {
        let panel = AreaPanel(frame: Self.frame)
        panel.area.mouseDown(with: try Self.mouse(.leftMouseDown, at: CGPoint(x: 40, y: 30)))
        panel.area.mouseDragged(with: try Self.mouse(.leftMouseDragged, at: CGPoint(x: 90, y: 80)))

        #expect(panel.area.selection?.rect == CGRect(x: 40, y: 30, width: 50, height: 50))
    }

    @Test func escapeCancelsAndOtherKeysAreIgnored() throws {
        let panel = AreaPanel(frame: Self.frame)
        var cancelled = 0
        panel.onCancel = { cancelled += 1 }

        panel.sendEvent(try Self.key(kVK_ANSI_A))
        #expect(cancelled == 0)
        panel.sendEvent(try Self.key(kVK_Escape))
        #expect(cancelled == 1)
    }

    @Test func coversEveryScreenAboveTheOtherWindows() throws {
        let display = try #require(NSScreen.screens.first)
        let selector = AreaSelector()
        selector.show(on: [display])
        defer { selector.hide() }

        let panel = try #require(selector.panels.first)
        #expect(selector.isVisible)
        #expect(panel.frame == display.frame)
        #expect(panel.level == .screenSaver)
        #expect(panel.takesKeys)
    }

    @Test func finishesOnceWithTheAreaOrNilWhenCancelled() throws {
        let display = try #require(NSScreen.screens.first)
        var results: [CGRect?] = []
        let selector = AreaSelector { results.append($0) }
        selector.show(on: [display])
        let panel = try #require(selector.panels.first)

        let start = CGPoint(x: 20, y: 20)
        try Self.drag(panel, from: start, to: CGPoint(x: 120, y: 90))
        panel.sendEvent(try Self.key(kVK_Escape))
        try Self.drag(panel, from: start, to: CGPoint(x: 120, y: 90))

        #expect(
            results == [
                CGRect(
                    x: display.frame.minX + 20, y: display.frame.minY + 20, width: 100, height: 70)
            ])
        #expect(!selector.isVisible)
        #expect(!panel.isVisible)

        selector.show(on: [display])
        let again = try #require(selector.panels.first)
        again.sendEvent(try Self.key(kVK_Escape))
        #expect(results.count == 2)
        #expect(results[1] == nil)
    }
}
