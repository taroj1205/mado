import AppKit

final class WidgetMoreButton: NSView {
    static let size: CGFloat = 22
    static let inset: CGFloat = 6
    private static let dot: CGFloat = 2.1
    private static let spacing: CGFloat = 3.4
    private static let shadowBlur: CGFloat = 6
    private static let shadowDrop: CGFloat = 2
    private static let shadowAlpha: CGFloat = 0.25
    private static let fillAlpha = (dark: 0.22, light: 0.1)
    private static let fill = WidgetTile.tone(.white, .black, fillAlpha)
    private static let half: CGFloat = 0.5

    override init(frame: NSRect) {
        super.init(frame: frame)
        let shade = NSShadow()
        shade.shadowBlurRadius = Self.shadowBlur
        shade.shadowOffset = NSSize(width: 0, height: -Self.shadowDrop)
        shade.shadowColor = .black.withAlphaComponent(Self.shadowAlpha)
        shadow = shade
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func draw(_: NSRect) {
        Self.fill.setFill()
        NSBezierPath(ovalIn: bounds).fill()
        NSColor.labelColor.setFill()
        for step in [-1, 0, 1] as [CGFloat] {
            let centre = NSPoint(x: bounds.midX + step * Self.spacing, y: bounds.midY)
            NSBezierPath(
                ovalIn: NSRect(
                    x: centre.x - Self.dot * Self.half, y: centre.y - Self.dot * Self.half,
                    width: Self.dot, height: Self.dot)
            ).fill()
        }
    }
}
