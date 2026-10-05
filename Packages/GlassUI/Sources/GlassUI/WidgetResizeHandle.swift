import AppKit

final class WidgetResizeHandle: NSView {
    private static let side: CGFloat = 24
    private static let inset: CGFloat = 4
    private static let line: CGFloat = 3
    private static let corner = (start: 270.0, end: 360.0)

    static var size: NSSize { NSSize(width: side, height: side) }

    var axes: Set<WidgetTile.Axis> = [] {
        didSet { unsafe window?.invalidateCursorRects(for: self) }
    }

    private var cursor: NSCursor {
        switch (axes.contains(.horizontal), axes.contains(.vertical)) {
        case (true, false): .resizeLeftRight
        case (false, true): .resizeUpDown

        default:
            if #available(macOS 15, *) {
                .frameResize(position: .bottomRight, directions: .all)
            } else {
                .crosshair
            }
        }
    }

    override func draw(_: NSRect) {
        let centre = NSPoint(
            x: bounds.maxX - WidgetTile.radius, y: bounds.minY + WidgetTile.radius)
        let arc = NSBezierPath()
        arc.appendArc(
            withCenter: centre, radius: WidgetTile.radius - Self.inset,
            startAngle: Self.corner.start, endAngle: Self.corner.end)
        arc.lineWidth = Self.line
        arc.lineCapStyle = .round
        NSColor.controlAccentColor.setStroke()
        arc.stroke()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: cursor)
    }
}
