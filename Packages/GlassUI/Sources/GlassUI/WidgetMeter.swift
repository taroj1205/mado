import AppKit

final class WidgetMeter: NSView {
    private static let textSize: CGFloat = 11
    private static let labelGap: CGFloat = 4
    private static let barGap: CGFloat = 4
    private static let barHeight: CGFloat = 4
    private static let barRadius: CGFloat = 2
    private static let trackAlpha = (dark: 0.14, light: 0.10)
    private static let fillAlpha = (dark: 0.85, light: 0.72)
    private static let track = WidgetTile.tone(.white, .black, trackAlpha)
    private static let fill = WidgetTile.tone(.white, .black, fillAlpha)

    let name = NSTextField(labelWithString: "")
    let value = NSTextField(labelWithString: "")
    private(set) var level = 0.0

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        name.textColor = .secondaryLabelColor
        name.lineBreakMode = .byTruncatingTail
        value.textColor = .labelColor
        value.setContentCompressionResistancePriority(.required, for: .horizontal)
        for label in [name, value] {
            label.font = .monospacedDigitSystemFont(ofSize: Self.textSize, weight: .semibold)
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
        }
        NSLayoutConstraint.activate([
            name.leadingAnchor.constraint(equalTo: leadingAnchor),
            name.topAnchor.constraint(equalTo: topAnchor),
            value.leadingAnchor.constraint(
                greaterThanOrEqualTo: name.trailingAnchor, constant: Self.labelGap),
            value.trailingAnchor.constraint(equalTo: trailingAnchor),
            value.firstBaselineAnchor.constraint(equalTo: name.firstBaselineAnchor),
            bottomAnchor.constraint(
                equalTo: name.bottomAnchor, constant: Self.barGap + Self.barHeight),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func show(_ meter: WidgetGrid.Meter) {
        name.stringValue = meter.name
        value.stringValue = meter.value
        level = min(max(meter.level, 0), 1)
        needsDisplay = true
    }

    override func draw(_: NSRect) {
        let bar = NSRect(x: 0, y: 0, width: bounds.width, height: Self.barHeight)
        Self.track.setFill()
        NSBezierPath(roundedRect: bar, xRadius: Self.barRadius, yRadius: Self.barRadius).fill()
        let filled = bar.divided(atDistance: bar.width * level, from: .minXEdge).slice
        Self.fill.setFill()
        NSBezierPath(roundedRect: filled, xRadius: Self.barRadius, yRadius: Self.barRadius).fill()
    }
}
