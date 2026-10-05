import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite struct ColourLoupeTests {
    static let screen = CGRect(x: 0, y: 0, width: 1_280, height: 800)
    static let card = CGSize(width: 240, height: 80)

    private static func grid(centre: NSColor) throws -> CGImage {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(
            unsafe CGContext(
                data: nil, width: 9, height: 9, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(NSColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 9, height: 9))
        context.setFillColor(centre.cgColor)
        context.fill(CGRect(x: 4, y: 4, width: 1, height: 1))
        return try #require(context.makeImage())
    }

    private static func key(_ code: Int, in panel: NSWindow) throws -> NSEvent {
        try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, characters: "",
                charactersIgnoringModifiers: "", isARepeat: false, keyCode: UInt16(code)))
    }

    private static func mouse(_ type: NSEvent.EventType, at point: CGPoint) throws -> NSEvent {
        try #require(
            NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: 0, windowNumber: 0,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
    }

    @Test func theCardSitsCentredTenPointsUnderTheLens() {
        let frames = ColourLoupe.frames(
            around: CGPoint(x: 613, y: 457), card: Self.card, in: Self.screen)
        #expect(frames.lens == CGRect(x: 520, y: 364, width: 186, height: 186))
        #expect(frames.card == CGRect(x: 493, y: 274, width: 240, height: 80))
    }

    @Test func theCardMovesAboveTheLensNearTheBottomAndStaysOnScreen() {
        let low = ColourLoupe.frames(
            around: CGPoint(x: 20, y: 120), card: Self.card, in: Self.screen)
        #expect(low.card.minY == low.lens.maxY + 10)
        #expect(low.card.minX == 0)
        let right = ColourLoupe.frames(
            around: CGPoint(x: 1_279, y: 400), card: Self.card, in: Self.screen)
        #expect(right.card.maxX == Self.screen.maxX)
        #expect(right.card.maxY == right.lens.minY - 10)
    }

    @Test func keysNudgePickAndCancel() throws {
        let panel = LoupePanel(frame: Self.screen)
        let expected: [(Int, ColourLoupe.Input?)] = [
            (kVK_LeftArrow, .nudged(across: -1, down: 0)),
            (kVK_RightArrow, .nudged(across: 1, down: 0)),
            (kVK_UpArrow, .nudged(across: 0, down: -1)),
            (kVK_DownArrow, .nudged(across: 0, down: 1)),
            (kVK_ANSI_H, .nudged(across: -1, down: 0)),
            (kVK_ANSI_L, .nudged(across: 1, down: 0)),
            (kVK_ANSI_K, .nudged(across: 0, down: -1)),
            (kVK_ANSI_J, .nudged(across: 0, down: 1)),
            (kVK_Return, .picked), (kVK_ANSI_KeypadEnter, .picked), (kVK_Escape, .cancelled),
            (kVK_ANSI_A, nil),
        ]
        for (code, input) in expected {
            #expect(LoupePanel.input(for: try Self.key(code, in: panel), in: panel) == input)
        }
    }

    @Test func movingReportsTheScreenPointAndReleasingPicks() throws {
        let panel = LoupePanel(frame: CGRect(x: 100, y: 50, width: 400, height: 300))
        let moved = try Self.mouse(.mouseMoved, at: CGPoint(x: 10, y: 20))
        #expect(LoupePanel.input(for: moved, in: panel) == .moved(CGPoint(x: 110, y: 70)))
        let dragged = try Self.mouse(.leftMouseDragged, at: CGPoint(x: 4, y: 5))
        #expect(LoupePanel.input(for: dragged, in: panel) == .moved(CGPoint(x: 104, y: 55)))
        let release = try Self.mouse(.leftMouseUp, at: .zero)
        #expect(LoupePanel.input(for: release, in: panel) == .picked)
        let press = try Self.mouse(.leftMouseDown, at: .zero)
        #expect(LoupePanel.input(for: press, in: panel) == nil)
    }

    @Test func showsTheReadingAroundTheSampledPixel() throws {
        let display = try #require(NSScreen.screens.first)
        let loupe = ColourLoupe()
        loupe.pointer = { CGPoint(x: display.frame.midX, y: display.frame.midY) }
        var inputs: [ColourLoupe.Input] = []
        loupe.onInput = { inputs.append($0) }
        loupe.show(on: [display])
        defer { loupe.hide() }
        let centre = CGPoint(x: display.frame.midX + 0.25, y: display.frame.midY + 0.25)
        loupe.show(
            ColourLoupe.Reading(
                grid: try Self.grid(centre: .systemBlue), swatch: .systemBlue, hex: "#0A84FF",
                detail: "rgb(10 132 255) · x 1024 y 612", centre: centre))

        let panel = try #require(loupe.panels.first)
        #expect(panel.takesKeys)
        #expect(panel.level == .screenSaver)
        #expect(loupe.lens.isDescendant(of: try #require(panel.contentView)))
        let lens = panel.convertToScreen(loupe.lens.frame)
        #expect(abs(lens.midX - centre.x) <= 0.5)
        #expect(abs(lens.midY - centre.y) <= 0.5)
        #expect(loupe.card.frame.maxY == loupe.lens.frame.minY - 10)
        #expect(loupe.card.frame.width == 240)
        #expect(loupe.hex.stringValue == "#0A84FF")
        #expect(loupe.detail.stringValue == "rgb(10 132 255) · x 1024 y 612")
        #expect(loupe.hint.stringValue == "Click copies · arrows or HJKL nudge 1 px · esc cancels")
        loupe.card.layoutSubtreeIfNeeded()
        let hint = loupe.hint.convert(loupe.hint.bounds, to: loupe.card)
        #expect(loupe.card.bounds.insetBy(dx: 8, dy: 8).contains(hint))
        #expect(hint.height > loupe.detail.frame.height * 1.5)
        #expect(loupe.card.accessibilityLabel() == "Colour #0A84FF, rgb(10 132 255) · x 1024 y 612")

        panel.sendEvent(try Self.key(kVK_DownArrow, in: panel))
        panel.sendEvent(try Self.key(kVK_Escape, in: panel))
        #expect(inputs == [.nudged(across: 0, down: 1), .cancelled])

        loupe.hide()
        #expect(!loupe.isVisible)
        #expect(!panel.isVisible)
        panel.sendEvent(try Self.key(kVK_Return, in: panel))
        #expect(inputs.count == 2)
    }

    @Test func theLensMagnifiesTheGridAndRingsTheMiddlePixel() throws {
        let lens = LoupeLens(frame: CGRect(x: 0, y: 0, width: 186, height: 186))
        lens.grid = try Self.grid(centre: .systemRed)
        let image = try #require(lens.snapshot())
        let rep = try #require(image.representations.first as? NSBitmapImageRep)
        let scale = CGFloat(rep.pixelsWide) / 186
        func colour(_ across: CGFloat, _ down: CGFloat) -> NSColor? {
            rep.colorAt(x: Int(across * scale), y: Int(down * scale))?.usingColorSpace(.sRGB)
        }
        let middle = try #require(colour(93, 93))
        #expect(middle.redComponent > 0.9)
        #expect(middle.greenComponent < 0.4)
        let mark = try #require(colour(84, 93))
        #expect(mark.redComponent > 0.95 && mark.greenComponent > 0.95)
        let outside = try #require(colour(60, 93))
        #expect(outside.redComponent < 0.05)
        let rim = try #require(colour(1.5, 93))
        #expect(rim.greenComponent > 0.8)
    }
}
