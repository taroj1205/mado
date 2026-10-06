import AppKit

final class DashedOutline: NSView {
    private static let slotEdge: CGFloat = 1.5
    private static let slotAlpha: CGFloat = 0.16
    private static let dash: CGFloat = 3
    private static let half: CGFloat = 0.5

    private let colour: NSColor
    private let fill: NSColor
    private let width: CGFloat
    private let radius: CGFloat

    init(colour: NSColor, width: CGFloat, fill: NSColor, radius: CGFloat) {
        self.colour = colour
        self.width = width
        self.fill = fill
        self.radius = radius
        super.init(frame: .zero)
        layerContentsRedrawPolicy = .duringViewResize
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    static func slot(radius: CGFloat) -> DashedOutline {
        let slot = DashedOutline(
            colour: .controlAccentColor, width: slotEdge,
            fill: .controlAccentColor.withAlphaComponent(slotAlpha), radius: radius)
        slot.isHidden = true
        return slot
    }

    override func draw(_: NSRect) {
        let inset = width * Self.half
        let corner = radius - inset
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: inset, dy: inset), xRadius: corner, yRadius: corner)
        fill.setFill()
        path.fill()
        path.lineWidth = width
        let pattern = [width * Self.dash, width * Self.dash]
        unsafe path.setLineDash(pattern, count: pattern.count, phase: 0)
        colour.setStroke()
        path.stroke()
    }
}
