import AppKit

final class AreaView: NSView {
    private static let scrimAlpha: CGFloat = 0.35
    private static let badgeAlpha: CGFloat = 0.7
    private static let badgeSize: CGFloat = 11
    private static let badgeRadius: CGFloat = 6
    private static let badgePadX: CGFloat = 8
    private static let badgePadY: CGFloat = 2
    private static let borderWidth: CGFloat = 1.5
    private static let half: CGFloat = 0.5
    private static let scrim = NSColor.black.withAlphaComponent(scrimAlpha)
    private static let badgeFill = NSColor.black.withAlphaComponent(badgeAlpha)
    private static let badgeFont = NSFont.monospacedDigitSystemFont(
        ofSize: badgeSize, weight: .medium)

    var onSelect: ((CGRect) -> Void)?
    private(set) var selection: AreaSelection?

    override init(frame: NSRect) {
        super.init(frame: frame)
        addTrackingArea(
            NSTrackingArea(
                rect: .zero, options: [.cursorUpdate, .activeAlways, .inVisibleRect], owner: self))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func point(of event: NSEvent) -> CGPoint {
        convert(event.locationInWindow, from: nil)
    }

    override func cursorUpdate(with _: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func mouseDown(with event: NSEvent) {
        selection = AreaSelection(from: point(of: event), in: bounds)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        selection?.drag(to: point(of: event))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        selection?.drag(to: point(of: event))
        defer {
            selection = nil
            needsDisplay = true
        }
        if let selection, selection.isUsable { onSelect?(selection.rect) }
    }

    override func draw(_: NSRect) {
        let shade = NSBezierPath(rect: bounds)
        if let rect = selection?.rect {
            shade.append(NSBezierPath(rect: rect))
            shade.windingRule = .evenOdd
        }
        Self.scrim.setFill()
        shade.fill()
        guard let selection, selection.isUsable else { return }
        NSColor.white.setStroke()
        let border = NSBezierPath(
            rect: selection.rect.insetBy(
                dx: Self.borderWidth * Self.half, dy: Self.borderWidth * Self.half))
        border.lineWidth = Self.borderWidth
        border.stroke()
        drawBadge(for: selection)
    }

    private func drawBadge(for selection: AreaSelection) {
        let text = NSAttributedString(
            string: selection.size,
            attributes: [.font: Self.badgeFont, .foregroundColor: NSColor.white])
        let content = text.size()
        let frame = selection.badge(
            sized: CGSize(
                width: content.width + Self.badgePadX + Self.badgePadX,
                height: content.height + Self.badgePadY + Self.badgePadY))
        Self.badgeFill.setFill()
        NSBezierPath(roundedRect: frame, xRadius: Self.badgeRadius, yRadius: Self.badgeRadius)
            .fill()
        text.draw(
            at: CGPoint(
                x: frame.minX + Self.badgePadX, y: frame.minY + Self.badgePadY))
    }
}
