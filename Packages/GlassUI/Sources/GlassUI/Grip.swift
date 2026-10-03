import AppKit

final class Grip: NSView {
    private static let across: CGFloat = 1.75
    private static let down: CGFloat = 3.5
    private static let radius: CGFloat = 0.875

    private let colour: NSColor

    init(colour: NSColor) {
        self.colour = colour
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func draw(_: NSRect) {
        colour.setFill()
        for column in [-Self.across, Self.across] {
            for row in [-Self.down, 0, Self.down] {
                let centre = NSRect(
                    x: bounds.midX + column, y: bounds.midY + row, width: 0, height: 0)
                NSBezierPath(ovalIn: centre.insetBy(dx: -Self.radius, dy: -Self.radius)).fill()
            }
        }
    }
}
