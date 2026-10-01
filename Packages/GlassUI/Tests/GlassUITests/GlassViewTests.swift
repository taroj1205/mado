import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct GlassViewTests {
    @Test func roundedRadiusIsClampedToHalfTheShortSide() {
        #expect(GlassView.Shape.rounded(12).radius(in: NSSize(width: 200, height: 100)) == 12)
        #expect(GlassView.Shape.rounded(80).radius(in: NSSize(width: 200, height: 100)) == 50)
        #expect(GlassView.Shape.rounded(-4).radius(in: NSSize(width: 200, height: 100)) == 0)
    }

    @Test func capsuleRadiusIsHalfTheShortSide() {
        #expect(GlassView.Shape.capsule.radius(in: NSSize(width: 200, height: 36)) == 18)
        #expect(GlassView.Shape.capsule.radius(in: NSSize(width: 30, height: 80)) == 15)
    }

    @Test func usesLiquidGlassOnlyWhereAvailable() {
        let view = GlassView(shape: .capsule)
        if #available(macOS 26, *) {
            #expect(view.effect is NSGlassEffectView)
        } else {
            #expect(view.effect is NSVisualEffectView)
        }
    }

    @Test func capsuleFollowsItsHeight() {
        let view = GlassView(shape: .capsule)
        view.frame = NSRect(x: 0, y: 0, width: 200, height: 40)
        view.layoutSubtreeIfNeeded()
        #expect(appliedRadius(view) == 20)
        view.frame.size.height = 24
        view.layoutSubtreeIfNeeded()
        #expect(appliedRadius(view) == 12)
    }

    @Test func liquidGlassIsClippedToItsShape() throws {
        guard #available(macOS 26, *) else { return }
        let view = GlassView(shape: .rounded(28))
        view.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
        view.layoutSubtreeIfNeeded()
        let layer = try #require(view.layer)
        #expect(layer.masksToBounds)
        #expect(layer.cornerCurve == .continuous)
        #expect(layer.cornerRadius == 28)
    }

    @Test func contentSitsInsideTheEffect() {
        let view = GlassView(shape: .rounded(12))
        let first = NSView()
        let second = NSView()
        view.contentView = first
        #expect(first.isDescendant(of: view.effect))
        view.contentView = second
        #expect(!first.isDescendant(of: view))
        #expect(second.isDescendant(of: view.effect))
    }

    @Test func sheenSitsUnderTheContentAndFollowsTheShape() {
        let view = GlassView(shape: .rounded(28))
        let content = NSView()
        view.contentView = content
        view.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
        view.layoutSubtreeIfNeeded()
        #expect(view.container.subviews.first === view.sheen)
        #expect(view.container.subviews.last === content)
        #expect(view.sheen.radius == 28)
    }

    @Test func sheenFollowsTheTheme() throws {
        let dark = try #require(NSAppearance(named: .darkAqua))
        let light = try #require(NSAppearance(named: .aqua))
        #expect(GlassSheen.tone(for: dark).sheen == GlassSheen.dark.sheen)
        #expect(GlassSheen.tone(for: light).sheen == GlassSheen.light.sheen)
    }

    @Test func onlyThePanelTakesTheMouseAndKeyboard() {
        let rect = NSRect(x: 0, y: 0, width: 200, height: 80)
        let hud = GlassPanel(kind: .hud, contentRect: rect, shape: .rounded(16))
        let panel = GlassPanel(kind: .panel, contentRect: rect, shape: .rounded(16))
        #expect(hud.ignoresMouseEvents)
        #expect(!panel.ignoresMouseEvents)
        #expect(panel.canBecomeKey)
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(!hud.canBecomeKey)
        #expect(hud.contentView === hud.glass)
    }

    @Test func panelHasItsWindowBeforeItIsShown() {
        let panel = GlassPanel(
            kind: .panel, contentRect: NSRect(x: 0, y: 0, width: 200, height: 80),
            shape: .rounded(16))
        #expect(!panel.isVisible)
        #expect(panel.windowNumber > 0)
    }

    func appliedRadius(_ view: GlassView) -> CGFloat? {
        if #available(macOS 26, *), let glass = view.effect as? NSGlassEffectView {
            return glass.cornerRadius
        }
        return (view.effect as? NSVisualEffectView)?.maskImage?.capInsets.top
    }
}
