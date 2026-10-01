import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct GlassViewTests {
    @Test func roundedRadiusIsClampedToHalfTheShortSide() {
        #expect(GlassView.Shape.rounded(12).radius(in: NSSize(width: 200, height: 100)) == 12)
        #expect(GlassView.Shape.rounded(80).radius(in: NSSize(width: 200, height: 100)) == 50)
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

    @Test func hudIgnoresTheMouse() {
        let rect = NSRect(x: 0, y: 0, width: 200, height: 80)
        let hud = GlassPanel(kind: .hud, contentRect: rect, shape: .rounded(16))
        let panel = GlassPanel(kind: .panel, contentRect: rect, shape: .rounded(16))
        #expect(hud.ignoresMouseEvents)
        #expect(!panel.ignoresMouseEvents)
        #expect(hud.contentView === hud.glass)
    }

    func appliedRadius(_ view: GlassView) -> CGFloat? {
        if #available(macOS 26, *), let glass = view.effect as? NSGlassEffectView {
            return glass.cornerRadius
        }
        return (view.effect as? NSVisualEffectView)?.maskImage?.capInsets.top
    }
}
