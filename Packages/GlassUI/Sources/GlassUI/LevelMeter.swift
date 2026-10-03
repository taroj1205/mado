import AppKit

final class LevelMeter: NSView {
    static let count = 12
    static let step: Duration = .milliseconds(100)
    private static let barWidth: CGFloat = 3
    private static let gap: CGFloat = 3
    private static let lowest: CGFloat = 6
    private static let highest: CGFloat = 24
    private static let half: CGFloat = 0.5

    private(set) var levels = Array(repeating: 0.0, count: count)
    private var loudest = 0.0
    private var stepped: ContinuousClock.Instant?

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: CGFloat(Self.count) * (Self.barWidth + Self.gap) - Self.gap,
            height: Self.highest)
    }

    static func height(for level: Double) -> CGFloat {
        lowest + (highest - lowest) * CGFloat(min(max(level, 0), 1))
    }

    func reset() {
        levels = Array(repeating: 0, count: Self.count)
        loudest = 0
        stepped = nil
        needsDisplay = true
    }

    func add(_ level: Double, at now: ContinuousClock.Instant) {
        loudest = max(loudest, level)
        if let stepped, stepped.duration(to: now) < Self.step { return }
        levels.removeFirst()
        levels.append(loudest)
        loudest = 0
        stepped = now
        needsDisplay = true
    }

    override func draw(_: NSRect) {
        NSColor.labelColor.setFill()
        let radius = Self.barWidth * Self.half
        for (index, level) in levels.enumerated() {
            let height = Self.height(for: level)
            let bar = NSRect(
                x: CGFloat(index) * (Self.barWidth + Self.gap),
                y: ((bounds.height - height) * Self.half).rounded(),
                width: Self.barWidth, height: height)
            NSBezierPath(roundedRect: bar, xRadius: radius, yRadius: radius).fill()
        }
    }
}
