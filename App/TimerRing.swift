import AppCore
import AppKit

final class TimerRing: NSView {
    private static let size: CGFloat = 84
    private static let line: CGFloat = 7
    private static let trackAlpha: CGFloat = 0.12
    private static let clockSize: CGFloat = 17
    private static let longClockSize: CGFloat = 13
    private static let longClock = 5
    private static let half: CGFloat = 0.5
    private static let top: CGFloat = 90
    private static let turn: CGFloat = 360

    private let clock = NSTextField(labelWithString: "")
    private var fraction = 0.0
    private var state = Timers.State.paused

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.size, height: Self.size)
    }

    private var tint: NSColor {
        switch state {
        case .running: .systemOrange
        case .done: .systemGreen
        case .paused: .secondaryLabelColor
        }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        clock.alignment = .center
        clock.translatesAutoresizingMaskIntoConstraints = false
        addSubview(clock)
        NSLayoutConstraint.activate([
            clock.centerXAnchor.constraint(equalTo: centerXAnchor),
            clock.centerYAnchor.constraint(equalTo: centerYAnchor),
            widthAnchor.constraint(equalToConstant: Self.size),
            heightAnchor.constraint(equalToConstant: Self.size),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func show(_ text: String, fraction: Double, state: Timers.State) {
        let points = text.count > Self.longClock ? Self.longClockSize : Self.clockSize
        clock.font = .monospacedDigitSystemFont(ofSize: points, weight: .bold)
        clock.stringValue = text
        self.fraction = min(1, max(0, fraction))
        self.state = state
        needsDisplay = true
        setAccessibilityLabel(text)
    }

    override func draw(_: NSRect) {
        let rect = bounds.insetBy(dx: Self.line * Self.half, dy: Self.line * Self.half)
        let track = NSBezierPath(ovalIn: rect)
        track.lineWidth = Self.line
        NSColor.labelColor.withAlphaComponent(Self.trackAlpha).setStroke()
        track.stroke()
        guard fraction > 0 else { return }
        let arc = NSBezierPath()
        arc.appendArc(
            withCenter: NSPoint(x: bounds.midX, y: bounds.midY), radius: rect.width * Self.half,
            startAngle: Self.top, endAngle: Self.top - Self.turn * fraction, clockwise: true)
        arc.lineWidth = Self.line
        arc.lineCapStyle = .round
        tint.setStroke()
        arc.stroke()
    }
}
