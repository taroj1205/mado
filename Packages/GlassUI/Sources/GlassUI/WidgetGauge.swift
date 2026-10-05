import AppKit

final class WidgetGauge: NSView {
    enum Style {
        case bar
        case ring
    }

    private static let trackAlpha = (dark: 0.14, light: 0.10)
    private static let fillAlpha = (dark: 0.85, light: 0.72)
    private static let track = WidgetTile.tone(.white, .black, trackAlpha)
    private static let fill = WidgetTile.tone(.white, .black, fillAlpha)
    private static let barHeight: CGFloat = 5
    private static let barGap: CGFloat = 5
    private static let ringLine: CGFloat = 5
    private static let ringMax: CGFloat = 60
    private static let ringGap: CGFloat = 5
    private static let smallRing: CGFloat = 50
    private static let top = 270.0
    private static let turn = 360.0
    private static let half: CGFloat = 0.5

    private var meter = WidgetGrid.Meter(name: "", value: "", level: 0)
    var style = Style.bar {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    static func height(of style: Style) -> CGFloat {
        switch style {
        case .bar:
            WidgetInk.caption.height + WidgetInk.gaugeValue.height + barGap + barHeight

        case .ring:
            ringMax + ringGap + WidgetInk.caption.height
        }
    }

    func show(_ meter: WidgetGrid.Meter) {
        guard meter != self.meter else { return }
        self.meter = meter
        needsDisplay = true
    }

    override func draw(_: NSRect) {
        switch style {
        case .bar: drawBar()
        case .ring: drawRing()
        }
    }

    private func drawBar() {
        let caption = WidgetInk.caption.height
        WidgetInk.draw(
            meter.name, WidgetInk.caption,
            in: NSRect(x: 0, y: 0, width: bounds.width, height: caption))
        let value = WidgetInk.gaugeValue.height
        WidgetInk.draw(
            meter.value, WidgetInk.gaugeValue,
            in: NSRect(x: 0, y: caption, width: bounds.width, height: value))
        let bar = NSRect(
            x: 0, y: caption + value + Self.barGap, width: bounds.width, height: Self.barHeight)
        let radius = Self.barHeight * Self.half
        Self.track.setFill()
        NSBezierPath(roundedRect: bar, xRadius: radius, yRadius: radius).fill()
        let level = min(max(meter.level, 0), 1)
        let filled = bar.divided(atDistance: bar.width * level, from: .minXEdge).slice
        Self.fill.setFill()
        NSBezierPath(roundedRect: filled, xRadius: radius, yRadius: radius).fill()
    }

    private func drawRing() {
        let caption = WidgetInk.caption.height
        let diameter = min(
            Self.ringMax, bounds.width, bounds.height - caption - Self.ringGap)
        let ring = NSRect(
            x: bounds.midX - diameter * Self.half, y: 0, width: diameter, height: diameter)
        let centre = NSPoint(x: ring.midX, y: ring.midY)
        let radius = (diameter - Self.ringLine) * Self.half
        let level = min(max(meter.level, 0), 1)
        Self.track.setStroke()
        stroke(from: Self.top, sweep: Self.turn, at: centre, radius: radius)
        Self.fill.setStroke()
        stroke(from: Self.top, sweep: Self.turn * level, at: centre, radius: radius)
        WidgetInk.draw(
            meter.value, diameter < Self.smallRing ? WidgetInk.smallRingValue : WidgetInk.ringValue,
            in: ring, align: .center)
        WidgetInk.draw(
            meter.name, WidgetInk.caption,
            in: NSRect(
                x: 0, y: ring.maxY + Self.ringGap, width: bounds.width, height: caption),
            align: .center)
    }

    private func stroke(from start: Double, sweep: Double, at centre: NSPoint, radius: CGFloat) {
        guard sweep > 0 else { return }
        let arc = NSBezierPath()
        arc.appendArc(
            withCenter: centre, radius: radius, startAngle: start, endAngle: start + sweep,
            clockwise: false)
        arc.lineWidth = Self.ringLine
        arc.lineCapStyle = .round
        arc.stroke()
    }
}
