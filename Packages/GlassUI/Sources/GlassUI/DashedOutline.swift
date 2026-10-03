import AppKit

final class DashedOutline: NSView {
    private static let dash: CGFloat = 3
    private static let half: CGFloat = 0.5

    private let colour: NSColor
    private let fill: NSColor
    private let width: CGFloat

    init(colour: NSColor, width: CGFloat, fill: NSColor) {
        self.colour = colour
        self.width = width
        self.fill = fill
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func draw(_: NSRect) {
        let inset = width * Self.half
        let radius = WidgetTile.radius - inset
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: inset, dy: inset), xRadius: radius, yRadius: radius)
        fill.setFill()
        path.fill()
        path.lineWidth = width
        let pattern = [width * Self.dash, width * Self.dash]
        unsafe path.setLineDash(pattern, count: pattern.count, phase: 0)
        colour.setStroke()
        path.stroke()
    }
}
