import AppCore
import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct GestureOverlayTests {
    private let overlay = GestureOverlay()

    @Test func moveNamesTheHeldKeysAndTheDisplayOnlyWhenThereAreSeveral() {
        let several = GestureOverlay.text(
            .move(held: [.function, .control], display: 2, displays: 3))
        #expect(several.title == "Move")
        #expect(several.detail == "fn ⌃ held · 2 of 3 displays")
        let one = GestureOverlay.text(.move(held: [.function, .control], display: 1, displays: 1))
        #expect(one.detail == "fn ⌃ held")
    }

    @Test func resizeShowsTheSizeInWholePoints() {
        let text = GestureOverlay.text(.resize(CGSize(width: 1_259.6, height: 900.2)))
        #expect(text.title == "Resize")
        #expect(text.detail == "1260 × 900")
    }

    @Test(.enabled(if: !NSScreen.screens.isEmpty, "Placing the HUD needs a screen"))
    func theOutlineCoversTheFrameAndTheHUDSitsCentredBelowIt() throws {
        let visible = try #require(NSScreen.screens.first).visibleFrame
        let frame = CGRect(x: visible.midX - 200, y: visible.midY - 100, width: 400, height: 300)
        overlay.show(frame, status: .resize(frame.size))
        defer { overlay.hide() }
        #expect(overlay.outline.isVisible && overlay.hud.isVisible)
        #expect(overlay.outline.frame.insetBy(dx: 1, dy: 1) == frame)
        let edge = try #require(overlay.outline.contentView)
        edge.layoutSubtreeIfNeeded()
        #expect(edge.subviews.first?.frame.size == frame.size)
        #expect(abs(overlay.hud.frame.midX - frame.midX) <= 1)
        #expect(overlay.hud.frame.maxY == frame.minY - 18)
        #expect(overlay.detail.stringValue == "400 × 300")

        overlay.hide()
        #expect(!overlay.outline.isVisible && !overlay.hud.isVisible)
    }

    @Test(.enabled(if: !NSScreen.screens.isEmpty, "Placing the HUD needs a screen"))
    func theHUDStaysOnScreenUnderAMaximisedWindow() throws {
        let visible = try #require(NSScreen.screens.first).visibleFrame
        overlay.show(visible, status: .resize(visible.size))
        defer { overlay.hide() }
        #expect(visible.contains(overlay.hud.frame))
    }
}
