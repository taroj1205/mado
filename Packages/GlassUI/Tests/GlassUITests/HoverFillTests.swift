import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct HoverFillTests {
    private final class BleedingRow: NSView {
        override var alignmentRectInsets: NSEdgeInsets {
            NSEdgeInsets(top: 0, left: HoverFillTests.bleed, bottom: 0, right: HoverFillTests.bleed)
        }
    }

    private static let bleed: CGFloat = 8
    private static let inner: CGFloat = 292

    private let host = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 40))

    @Test func fillsItsHostAndFollowsResizes() {
        let fill = HoverFill.install(in: host, radius: 9)
        #expect(fill.frame == host.bounds)
        host.setFrameSize(NSSize(width: 180, height: 30))
        #expect(fill.frame == host.bounds)
        #expect(host.subviews.first === fill)
    }

    @Test func coversAHostWhoseLayoutRectIsInsetFromItsFrame() {
        let row = BleedingRow()
        let fill = HoverFill.install(in: row, radius: 6)
        let stack = NSStackView(views: [row])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        row.widthAnchor.constraint(equalToConstant: Self.inner).isActive = true
        row.heightAnchor.constraint(equalToConstant: 24).isActive = true
        stack.layoutSubtreeIfNeeded()
        #expect(row.frame.width == Self.inner + Self.bleed + Self.bleed)
        #expect(fill.frame == row.bounds)
    }

    @Test func tintsOnlyWhileThePointerIsInside() {
        let fill = HoverFill.install(in: host, radius: 9)
        fill.updateLayer()
        #expect(fill.layer?.backgroundColor == nil)
        fill.mouseEntered(with: NSEvent())
        fill.updateLayer()
        #expect(fill.layer?.backgroundColor != nil)
        fill.mouseExited(with: NSEvent())
        fill.updateLayer()
        #expect(fill.layer?.backgroundColor == nil)
    }

    @Test func hidingTheHostClearsTheTint() {
        let fill = HoverFill.install(in: host, radius: 9)
        fill.mouseEntered(with: NSEvent())
        #expect(fill.isHovered)
        host.isHidden = true
        #expect(!fill.isHovered)
    }

    @Test func letsClicksReachTheHost() {
        let fill = HoverFill.install(in: host, radius: 9)
        #expect(fill.hitTest(NSPoint(x: 10, y: 10)) == nil)
        #expect(host.hitTest(NSPoint(x: 10, y: 10)) === host)
    }

    @Test func resultRowsKeepTheirTintInsideTheRowFill() throws {
        let row = ResultRowView(frame: NSRect(x: 0, y: 0, width: 300, height: 41))
        row.trailingInset = 20
        row.layoutSubtreeIfNeeded()
        let fill = try #require(row.subviews.compactMap { $0 as? HoverFill }.first)
        #expect(fill.frame == NSRect(x: 0, y: 0, width: 280, height: 40))
        row.radius = 5
        #expect(fill.radius == 5)
    }

    @Test func accentCapsulesRoundTheirTintToThePill() throws {
        let button = CapsuleButton.accent("Done", keys: ["↵"], height: 30)
        let fill = try #require(button.contentView?.subviews.compactMap { $0 as? HoverFill }.first)
        #expect(fill.radius == 15)
    }
}
