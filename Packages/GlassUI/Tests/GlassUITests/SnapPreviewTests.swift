import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct SnapPreviewTests {
    private let preview = SnapPreview()
    private let screen = NSScreen.screens[0]

    private var window: CGRect {
        CGRect(x: screen.frame.minX + 200, y: screen.frame.minY + 150, width: 600, height: 400)
    }

    private var target: CGRect {
        CGRect(
            x: screen.frame.minX, y: screen.frame.minY, width: screen.frame.width / 2,
            height: screen.frame.height)
    }

    private func local(_ rect: CGRect) -> CGRect {
        rect.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY)
    }

    @Test func coversTheScreenAndStartsHiddenOverTheWindow() {
        preview.begin(from: window, on: screen)
        defer { preview.panel.orderOut(nil) }

        #expect(preview.panel.frame == screen.frame)
        #expect(preview.panel.isVisible)
        #expect(preview.box == local(window))
        #expect(preview.outline.opacity == 0)
        #expect(preview.outline.contents != nil)
    }

    @Test func springsTheOutlineToTheTargetWithoutResizingThePanel() {
        preview.reducesMotion = { false }
        preview.begin(from: window, on: screen)
        defer { preview.panel.orderOut(nil) }

        preview.show(target)

        #expect(preview.panel.frame == screen.frame)
        #expect(preview.box == local(target))
        #expect(preview.outline.opacity == 1)
        #expect(preview.outline.animation(forKey: "position") is CASpringAnimation)
        #expect(preview.outline.animation(forKey: "bounds") is CASpringAnimation)
        #expect(preview.outline.animation(forKey: "opacity") != nil)
    }

    @Test func switchesAtOnceWhenReduceMotionIsOn() {
        preview.reducesMotion = { true }
        preview.begin(from: window, on: screen)
        defer { preview.panel.orderOut(nil) }

        preview.show(target)

        #expect(preview.box == local(target))
        #expect(preview.outline.opacity == 1)
        #expect(preview.outline.animationKeys() == nil)
    }

    @Test func fadesBackOverTheWindowWhenThereIsNoTarget() {
        preview.reducesMotion = { true }
        preview.begin(from: window, on: screen)
        defer { preview.panel.orderOut(nil) }
        preview.show(target)

        preview.show(nil)

        #expect(preview.box == local(window))
        #expect(preview.outline.opacity == 0)
    }

    @Test(arguments: [false, true])
    func endingFadesOutThenHidesThePanel(reducesMotion: Bool) async throws {
        preview.reducesMotion = { reducesMotion }
        preview.begin(from: window, on: screen)
        preview.show(target)

        preview.end()

        #expect(preview.outline.opacity == 0)
        try await Task.sleep(for: .milliseconds(300))
        #expect(!preview.panel.isVisible)
    }

    @Test func pressingAgainDuringTheFadeKeepsThePanel() async throws {
        preview.reducesMotion = { false }
        preview.begin(from: window, on: screen)
        defer { preview.panel.orderOut(nil) }
        preview.show(target)
        preview.end()

        preview.begin(from: window, on: screen)
        try await Task.sleep(for: .milliseconds(300))

        #expect(preview.panel.isVisible)
    }
}
