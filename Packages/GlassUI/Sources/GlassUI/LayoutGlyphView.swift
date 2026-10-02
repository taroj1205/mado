public import AppKit

public final class LayoutGlyphView: NSView {
    private static let width: CGFloat = 30
    private static let height: CGFloat = 20
    private static let lineWidth: CGFloat = 1.5
    private static let radius: CGFloat = 4
    private static let areaRadius: CGFloat = 2
    private static let half: CGFloat = 0.5
    private static let outlineAlpha = 0.45
    private static let outlineColour = SheetForm.adaptive(
        dark: .white.withAlphaComponent(outlineAlpha),
        light: .black.withAlphaComponent(outlineAlpha))

    private let area: CGRect

    override public var isFlipped: Bool { true }
    override public var intrinsicContentSize: NSSize {
        NSSize(width: Self.width, height: Self.height)
    }

    public init(area: CGRect) {
        self.area = area
        super.init(frame: NSRect(x: 0, y: 0, width: Self.width, height: Self.height))
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override public func draw(_: NSRect) {
        let edge = Self.lineWidth * Self.half
        let outline = NSBezierPath(
            roundedRect: bounds.insetBy(dx: edge, dy: edge), xRadius: Self.radius,
            yRadius: Self.radius)
        outline.lineWidth = Self.lineWidth
        Self.outlineColour.setStroke()
        outline.stroke()
        let inner = bounds.insetBy(dx: Self.lineWidth, dy: Self.lineWidth)
        let filled = CGRect(
            x: inner.minX + area.minX * inner.width, y: inner.minY + area.minY * inner.height,
            width: area.width * inner.width, height: area.height * inner.height)
        guard !filled.isEmpty else { return }
        NSColor.controlAccentColor.setFill()
        NSBezierPath(roundedRect: filled, xRadius: Self.areaRadius, yRadius: Self.areaRadius)
            .fill()
    }
}
