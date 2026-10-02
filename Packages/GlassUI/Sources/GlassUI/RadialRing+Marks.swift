import AppKit

extension RadialRing {
    private static let glassRadius: CGFloat = 52
    private static let holeRadius: CGFloat = 28
    private static let bandRadius: CGFloat = 40
    private static let bandWidth: CGFloat = 24
    private static let arcHalfDegrees: CGFloat = 24
    private static let edgeWidth: CGFloat = 1
    private static let crossReach: CGFloat = 5.5
    private static let crossWidth: CGFloat = 2
    private static let glowRadius: CGFloat = 3
    private static let glowOpacity: Float = 0.55
    private static let tintGrey: CGFloat = 0.071
    private static let tintBlue: CGFloat = 0.094
    private static let tintAlpha: CGFloat = 0.46
    private static let shadeAlpha: CGFloat = 0.35
    private static let rimAlpha: CGFloat = 0.16
    private static let holeEdgeAlpha: CGFloat = 0.12
    private static let crossAlpha: CGFloat = 0.85

    private static func circle(_ radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.addEllipse(
            in: CGRect(origin: centre, size: .zero).insetBy(dx: -radius, dy: -radius))
        return path
    }

    func addDonut() {
        let inset = Self.centre.x - Self.glassRadius
        glass.frame = bounds.insetBy(dx: inset, dy: inset)
        glass.sheen.isHidden = true
        let fill = NSView()
        fill.wantsLayer = true
        fill.layer?.backgroundColor =
            NSColor(
                srgbRed: Self.tintGrey, green: Self.tintGrey, blue: Self.tintBlue,
                alpha: Self.tintAlpha
            ).cgColor
        glass.contentView = fill
        let path = CGMutablePath()
        path.addEllipse(in: glass.bounds)
        let hole = Self.glassRadius - Self.holeRadius
        path.addEllipse(in: glass.bounds.insetBy(dx: hole, dy: hole))
        donut.path = path
        donut.fillRule = .evenOdd
        donut.frame = glass.bounds
        glass.wantsLayer = true
        glass.layer?.mask = donut
        addSubview(glass)
    }

    func addMarks() {
        marks.frame = bounds
        marks.wantsLayer = true
        addEdges()
        band.path = Self.circle(Self.bandRadius)
        addMark(band, nil, width: Self.bandWidth)
        let path = CGMutablePath()
        path.addArc(
            center: Self.centre, radius: Self.bandRadius,
            startAngle: Self.radians(-Self.arcHalfDegrees),
            endAngle: Self.radians(Self.arcHalfDegrees), clockwise: false)
        arc.path = path
        arc.shadowOffset = .zero
        arc.shadowRadius = Self.glowRadius
        arc.shadowOpacity = Self.glowOpacity
        addMark(arc, nil, width: Self.bandWidth)
        addCross()
        addSubview(marks)
    }

    private func addEdges() {
        let offset = Self.edgeWidth * Self.half
        let edges: [(CGFloat, NSColor)] = [
            (Self.glassRadius + offset, .black.withAlphaComponent(Self.shadeAlpha)),
            (Self.glassRadius - offset, .white.withAlphaComponent(Self.rimAlpha)),
            (Self.holeRadius + offset, .white.withAlphaComponent(Self.holeEdgeAlpha)),
        ]
        for (radius, colour) in edges {
            let edge = CAShapeLayer()
            edge.path = Self.circle(radius)
            addMark(edge, colour, width: Self.edgeWidth)
        }
    }

    private func addCross() {
        let lines = CGMutablePath()
        let low = Self.centre.x - Self.crossReach
        let high = Self.centre.x + Self.crossReach
        lines.addLines(between: [CGPoint(x: low, y: low), CGPoint(x: high, y: high)])
        lines.addLines(between: [CGPoint(x: high, y: low), CGPoint(x: low, y: high)])
        cross.path = lines
        cross.lineCap = .round
        addMark(cross, .white.withAlphaComponent(Self.crossAlpha), width: Self.crossWidth)
    }

    private func addMark(_ layer: CAShapeLayer, _ colour: NSColor?, width: CGFloat) {
        layer.frame = bounds
        layer.fillColor = nil
        layer.strokeColor = colour?.cgColor
        layer.lineWidth = width
        marks.layer?.addSublayer(layer)
    }
}
