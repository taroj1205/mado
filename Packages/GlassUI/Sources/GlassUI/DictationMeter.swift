import AppKit

final class DictationMeter: NSView {
    static let bars = 12
    private static let barWidth: CGFloat = 3
    private static let gap: CGFloat = 3
    private static let radius: CGFloat = 1.5
    private static let minHeight: CGFloat = 6
    private static let maxHeight: CGFloat = 24
    private static let floor: Float = -50
    private static let decibelsPerDecade: Float = 20
    private static let half: CGFloat = 0.5

    private(set) var heights = Array(repeating: minHeight, count: bars)

    override var intrinsicContentSize: NSSize {
        let count = CGFloat(Self.bars)
        return NSSize(
            width: count * Self.barWidth + (count - 1) * Self.gap, height: Self.maxHeight)
    }

    init() {
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.levelIndicator)
        setAccessibilityLabel("Input level")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    static func height(rms: Float) -> CGFloat {
        let decibels = decibelsPerDecade * log10(max(rms, .leastNonzeroMagnitude))
        let level = CGFloat(min(max((decibels - floor) / -floor, 0), 1))
        return minHeight + level * (maxHeight - minHeight)
    }

    func push(_ rms: Float) {
        heights.removeFirst()
        heights.append(Self.height(rms: rms))
        setAccessibilityValue((heights.last ?? Self.minHeight) / Self.maxHeight)
        needsDisplay = true
    }

    func reset() {
        heights = Array(repeating: Self.minHeight, count: Self.bars)
        needsDisplay = true
    }

    override func draw(_: NSRect) {
        NSColor.labelColor.setFill()
        for (index, height) in heights.enumerated() {
            let bar = CGRect(
                x: CGFloat(index) * (Self.barWidth + Self.gap),
                y: ((bounds.height - height) * Self.half).rounded(),
                width: Self.barWidth, height: height)
            NSBezierPath(roundedRect: bar, xRadius: Self.radius, yRadius: Self.radius).fill()
        }
    }
}
