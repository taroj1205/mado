import AppKit

final class RemoveBadge: NSView {
    private static let grey: CGFloat = 0.353
    private static let blue: CGFloat = 0.392
    private static let alpha: CGFloat = 0.95
    private static let fill = NSColor(srgbRed: grey, green: grey, blue: blue, alpha: alpha)
    private static let lineLength: CGFloat = 7
    private static let lineWidth: CGFloat = 1.5
    private static let shadowBlur: CGFloat = 6
    private static let shadowDrop: CGFloat = 2
    private static let shadowAlpha: CGFloat = 0.4
    private static let half: CGFloat = 0.5

    override init(frame: NSRect) {
        super.init(frame: frame)
        let shade = NSShadow()
        shade.shadowBlurRadius = Self.shadowBlur
        shade.shadowOffset = NSSize(width: 0, height: -Self.shadowDrop)
        shade.shadowColor = .black.withAlphaComponent(Self.shadowAlpha)
        shadow = shade
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func draw(_: NSRect) {
        Self.fill.setFill()
        NSBezierPath(ovalIn: bounds).fill()
        let line = NSBezierPath()
        line.move(to: NSPoint(x: bounds.midX - Self.lineLength * Self.half, y: bounds.midY))
        line.line(to: NSPoint(x: bounds.midX + Self.lineLength * Self.half, y: bounds.midY))
        line.lineWidth = Self.lineWidth
        line.lineCapStyle = .round
        NSColor.white.setStroke()
        line.stroke()
    }
}
