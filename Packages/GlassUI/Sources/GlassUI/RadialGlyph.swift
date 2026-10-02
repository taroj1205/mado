import AppKit

@MainActor
enum RadialGlyph {
    private static let width: CGFloat = 22
    private static let height: CGFloat = 16
    static let size = CGSize(width: width, height: height)
    private static let lineWidth: CGFloat = 1.5
    private static let radius: CGFloat = 4
    private static let padding: CGFloat = 1.5
    private static let areaRadius: CGFloat = 1.5
    private static let half: CGFloat = 0.5

    static func colours(outline: Double, area: Double) -> (outline: NSColor, area: NSColor) {
        (tone(outline), tone(area))
    }

    static func draw(
        _ area: CGRect, at origin: CGPoint, colours: (outline: NSColor, area: NSColor)
    ) {
        let frame = CGRect(origin: origin, size: size)
        let edge = lineWidth * half
        let outline = NSBezierPath(
            roundedRect: frame.insetBy(dx: edge, dy: edge), xRadius: radius, yRadius: radius)
        outline.lineWidth = lineWidth
        colours.outline.setStroke()
        outline.stroke()
        let inner = frame.insetBy(dx: lineWidth + padding, dy: lineWidth + padding)
        let filled = CGRect(
            x: inner.minX + area.minX * inner.width, y: inner.minY + area.minY * inner.height,
            width: area.width * inner.width, height: area.height * inner.height)
        guard !filled.isEmpty else { return }
        colours.area.setFill()
        NSBezierPath(roundedRect: filled, xRadius: areaRadius, yRadius: areaRadius).fill()
    }

    private static func tone(_ alpha: Double) -> NSColor {
        SheetForm.adaptive(
            dark: .white.withAlphaComponent(alpha), light: .black.withAlphaComponent(alpha))
    }
}
