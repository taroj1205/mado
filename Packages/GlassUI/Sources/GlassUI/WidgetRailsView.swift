import AppKit

final class WidgetRailsView: NSView {
    struct Mark {
        let spot: WidgetGrid.Spot
        let frame: CGRect
    }

    struct Model {
        var panel = CGRect.zero
        var shelf: CGFloat = 0
        var pucks: [CGPoint] = []
        var hot: WidgetGrid.Side?
        var ghost: Mark?
        var refused: Mark?
    }

    private static let radius: CGFloat = 20
    private static let edge: CGFloat = 1.5
    private static let dash: CGFloat = 4.5
    private static let captionGap: CGFloat = 6
    private static let captionInset: CGFloat = 4
    private static let captionSize: CGFloat = 10.5
    private static let captionKern: CGFloat = 0.9
    private static let puckWidth: CGFloat = 30
    private static let puckHeight: CGFloat = 5
    private static let labelGap: CGFloat = 10
    private static let ghostAlpha: CGFloat = 0.16
    private static let warnAlpha: CGFloat = 0.10
    private static let half: CGFloat = 0.5
    private static let dockAlpha = (dark: 0.16, light: 0.18)
    private static let fillAlpha = (dark: 0.025, light: 0.22)
    static let dock = WidgetTile.tone(.white, .black, dockAlpha)
    private static let dockFill = WidgetTile.tone(.white, .white, fillAlpha)

    let label = WidgetSpotLabel()
    var onDrag: ((String?, NSPoint, Any?) -> NSDragOperation)?
    var onDrop: ((String?) -> Bool)?

    var model = Model() {
        didSet {
            needsDisplay = true
            placeLabel()
        }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(false)
        label.isHidden = true
        addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func noRoom(_ side: WidgetGrid.Side) -> String {
        switch side {
        case .left: "NO ROOM ON THE LEFT"
        case .right: "NO ROOM ON THE RIGHT"
        case .above, .panel: "NO ROOM ABOVE"
        }
    }

    private static func caption(_ side: WidgetGrid.Side) -> String {
        switch side {
        case .left: "LEFT"
        case .right: "RIGHT"
        case .above, .panel: "ABOVE THE PANEL"
        }
    }

    private static func outline(_ rect: CGRect, radius: CGFloat, stroke: NSColor, fill: NSColor) {
        let inset = edge * half
        let path = NSBezierPath(
            roundedRect: rect.insetBy(dx: inset, dy: inset), xRadius: radius, yRadius: radius)
        fill.setFill()
        path.fill()
        path.lineWidth = edge
        let pattern = [dash, dash]
        unsafe path.setLineDash(pattern, count: pattern.count, phase: 0)
        stroke.setStroke()
        path.stroke()
    }

    private static func write(_ text: String, at point: CGPoint, colour: NSColor) {
        NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: captionSize, weight: .semibold),
                .kern: captionKern, .foregroundColor: colour,
            ]
        )
        .draw(at: point)
    }

    override func draw(_: NSRect) {
        drawRails()
        Self.dock.setFill()
        for point in model.pucks {
            let rect = CGRect(
                x: point.x - Self.puckWidth * Self.half, y: point.y - Self.puckHeight * Self.half,
                width: Self.puckWidth, height: Self.puckHeight)
            let round = Self.puckHeight * Self.half
            NSBezierPath(roundedRect: rect, xRadius: round, yRadius: round).fill()
        }
        if let ghost = model.ghost {
            Self.outline(
                ghost.frame, radius: WidgetTile.radius, stroke: .controlAccentColor,
                fill: .controlAccentColor.withAlphaComponent(Self.ghostAlpha))
        }
        if let refused = model.refused {
            Self.outline(
                refused.frame, radius: WidgetTile.radius, stroke: .systemOrange,
                fill: .systemOrange.withAlphaComponent(Self.warnAlpha))
        }
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        draggingUpdated(sender)
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard let window = unsafe window else { return [] }
        return onDrag?(
            sender.draggingPasteboard.string(forType: WidgetGrid.dragType),
            window.convertPoint(toScreen: sender.draggingLocation), sender.draggingSource) ?? []
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        if let sender {
            _ = draggingUpdated(sender)
        }
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        onDrop?(sender.draggingPasteboard.string(forType: WidgetGrid.dragType)) ?? false
    }

    private func drawRails() {
        let panel = model.panel
        let outward = WidgetGrid.sideGap + WidgetGrid.sideWidth
        let rails: [(WidgetGrid.Side, CGRect)] = [
            (
                .left,
                CGRect(
                    x: panel.minX - outward, y: panel.minY, width: WidgetGrid.sideWidth,
                    height: panel.height)
            ),
            (
                .right,
                CGRect(
                    x: panel.maxX + WidgetGrid.sideGap, y: panel.minY, width: WidgetGrid.sideWidth,
                    height: panel.height)
            ),
            (
                .above,
                CGRect(
                    x: panel.minX, y: panel.maxY + WidgetGrid.lift, width: panel.width,
                    height: model.shelf)
            ),
        ]
        for (side, rect) in rails {
            let refused = model.refused?.spot.side == side
            let colour: NSColor =
                refused ? .systemOrange : model.hot == side ? .controlAccentColor : Self.dock
            Self.outline(rect, radius: Self.radius, stroke: colour, fill: Self.dockFill)
            Self.write(
                refused ? Self.noRoom(side) : Self.caption(side),
                at: CGPoint(x: rect.minX + Self.captionInset, y: rect.maxY + Self.captionGap),
                colour: refused ? .systemOrange : .tertiaryLabelColor)
        }
    }

    private func placeLabel() {
        if let refused = model.refused {
            label.show("No room — try another spot", symbol: "nosign", tint: .systemOrange)
            label.frame = labelFrame(beside: refused)
        } else if let ghost = model.ghost {
            label.show(ghost.spot.title, symbol: "checkmark", tint: .controlAccentColor)
            label.frame = labelFrame(beside: ghost)
        }
        label.isHidden = model.ghost == nil && model.refused == nil
    }

    private func labelFrame(beside mark: Mark) -> CGRect {
        let size = label.fittingSize
        let top =
            mark.spot.side == .above
            ? mark.frame.maxY + Self.labelGap + size.height : mark.frame.minY - Self.labelGap
        return CGRect(
            x: mark.frame.midX - size.width * Self.half, y: top - size.height, width: size.width,
            height: size.height)
    }
}
