import AppKit

final class LoupeLens: NSView {
    static let diameter: CGFloat = 180
    static let rim: CGFloat = 3
    static let size = diameter + rim + rim
    private static let rimAlpha = 0.9
    private static let markWidth: CGFloat = 2
    private static let shadowAlpha = 0.5
    private static let shadowBlur: CGFloat = 30
    private static let shadowDrop: CGFloat = -12
    private static let half: CGFloat = 0.5

    var grid: CGImage? {
        didSet { needsDisplay = true }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        let drop = NSShadow()
        drop.shadowColor = .black.withAlphaComponent(Self.shadowAlpha)
        drop.shadowBlurRadius = Self.shadowBlur
        drop.shadowOffset = NSSize(width: 0, height: Self.shadowDrop)
        shadow = drop
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func draw(_: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let inner = bounds.insetBy(dx: Self.rim, dy: Self.rim)
        context.saveGState()
        context.addEllipse(in: inner)
        context.clip()
        context.setFillColor(NSColor.black.cgColor)
        context.fill(inner)
        if let grid, grid.width > 0 {
            context.interpolationQuality = .none
            context.draw(grid, in: inner)
            let cell = inner.width / CGFloat(grid.width)
            let offset = (inner.width - cell) * Self.half
            let mark = NSBezierPath(
                rect: CGRect(
                    x: inner.minX + offset, y: inner.minY + offset, width: cell, height: cell
                )
                .insetBy(dx: Self.markWidth * Self.half, dy: Self.markWidth * Self.half))
            mark.lineWidth = Self.markWidth
            NSColor.white.setStroke()
            mark.stroke()
        }
        context.restoreGState()
        let ring = NSBezierPath(
            ovalIn: bounds.insetBy(dx: Self.rim * Self.half, dy: Self.rim * Self.half))
        ring.lineWidth = Self.rim
        NSColor.white.withAlphaComponent(Self.rimAlpha).setStroke()
        ring.stroke()
    }
}
