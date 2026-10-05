import AppKit

@MainActor
enum DragCard {
    private static let edge: CGFloat = 1.5
    private static let alpha: CGFloat = 0.92
    private static let tilt: CGFloat = -2
    private static let halfTurn: CGFloat = 180
    private static let half: CGFloat = 0.5

    static func make(of view: NSView, showing content: NSView, radius: CGFloat) -> (
        frame: CGRect, image: NSImage?
    ) {
        let bounds = view.bounds
        let angle = tilt * .pi / halfTurn
        let turned = bounds.applying(CGAffineTransform(rotationAngle: angle)).size
        let frame = CGRect(
            x: bounds.midX - turned.width * half, y: bounds.midY - turned.height * half,
            width: turned.width, height: turned.height)
        guard let picture = content.snapshot() else { return (frame, nil) }
        let tile = CGRect(origin: .zero, size: bounds.size)
        let path = NSBezierPath(
            roundedRect: tile.insetBy(dx: edge * half, dy: edge * half),
            xRadius: radius, yRadius: radius)
        path.lineWidth = edge
        let fill = NSColor.windowBackgroundColor.withAlphaComponent(alpha)
        let appearance = view.effectiveAppearance
        let image = NSImage(size: turned, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.translateBy(x: rect.midX, y: rect.midY)
            context.rotate(by: angle)
            context.translateBy(x: -tile.midX, y: -tile.midY)
            appearance.performAsCurrentDrawingAppearance {
                fill.setFill()
                path.fill()
                picture.draw(in: tile)
                NSColor.controlAccentColor.setStroke()
                path.stroke()
            }
            return true
        }
        return (frame, image)
    }
}
