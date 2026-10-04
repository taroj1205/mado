import AppKit

final class WidgetSpan: NSView {
    private static let textSize: CGFloat = 11
    private static let labelGap: CGFloat = 5
    private static let barHeight: CGFloat = 4
    private static let barRadius: CGFloat = 2
    private static let dotSize: CGFloat = 7
    private static let dotRadius: CGFloat = 3.5
    private static let ringWidth: CGFloat = 1.5
    private static let ringAlpha: CGFloat = 0.25

    let low = NSTextField(labelWithString: "")
    let high = NSTextField(labelWithString: "")
    private let bar = NSView()
    private var span: WidgetGrid.Span?

    var position: Double { span.map { min(max($0.position, 0), 1) } ?? 0 }

    init() {
        super.init(frame: .zero)
        bar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bar)
        for label in [low, high] {
            label.font = .monospacedDigitSystemFont(ofSize: Self.textSize, weight: .medium)
            label.textColor = .secondaryLabelColor
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
            label.setContentHuggingPriority(.required, for: .horizontal)
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
        }
        NSLayoutConstraint.activate([
            low.leadingAnchor.constraint(equalTo: leadingAnchor),
            low.topAnchor.constraint(equalTo: topAnchor),
            low.bottomAnchor.constraint(equalTo: bottomAnchor),
            bar.leadingAnchor.constraint(equalTo: low.trailingAnchor, constant: Self.labelGap),
            bar.trailingAnchor.constraint(equalTo: high.leadingAnchor, constant: -Self.labelGap),
            bar.centerYAnchor.constraint(equalTo: low.centerYAnchor),
            bar.heightAnchor.constraint(equalToConstant: Self.dotSize),
            high.trailingAnchor.constraint(equalTo: trailingAnchor),
            high.firstBaselineAnchor.constraint(equalTo: low.firstBaselineAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func show(_ span: WidgetGrid.Span) {
        self.span = span
        low.stringValue = span.low
        high.stringValue = span.high
        needsDisplay = true
    }

    override func draw(_: NSRect) {
        guard let span else { return }
        let frame = bar.frame
        let track = NSRect(
            x: frame.minX, y: frame.midY - Self.barRadius, width: frame.width,
            height: Self.barHeight)
        NSGradient(starting: span.cold, ending: span.warm)?.draw(
            in: NSBezierPath(roundedRect: track, xRadius: Self.barRadius, yRadius: Self.barRadius),
            angle: 0)
        let travel = track.width - Self.dotSize
        let centre = NSPoint(
            x: track.minX + Self.dotRadius + travel * position, y: track.midY)
        let dot = NSRect(
            x: centre.x - Self.dotRadius, y: centre.y - Self.dotRadius, width: Self.dotSize,
            height: Self.dotSize)
        let ring = NSBezierPath(ovalIn: dot)
        NSColor.white.setFill()
        ring.fill()
        NSColor.black.withAlphaComponent(Self.ringAlpha).setStroke()
        ring.lineWidth = Self.ringWidth
        ring.stroke()
    }
}
