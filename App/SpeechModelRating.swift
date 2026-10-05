import AppCore
import AppKit

final class SpeechModelRating: NSView {
    private static let count = SpeechModel.Level.highest.rawValue
    private static let segmentWidth: CGFloat = 8
    private static let segmentHeight: CGFloat = 5
    private static let segment = NSSize(width: segmentWidth, height: segmentHeight)
    private static let gap: CGFloat = 2
    private static let radius: CGFloat = 2
    private static let half: CGFloat = 0.5

    private let value: Int

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: CGFloat(Self.count) * (Self.segment.width + Self.gap) - Self.gap,
            height: Self.segment.height)
    }

    init(_ level: SpeechModel.Level, named name: String) {
        value = level.rawValue
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.levelIndicator)
        setAccessibilityLabel(name)
        setAccessibilityMinValue(0)
        setAccessibilityMaxValue(Self.count)
        setAccessibilityValue(value)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func draw(_: NSRect) {
        for index in 0..<Self.count {
            (index < value ? NSColor.controlAccentColor : .quaternaryLabelColor).setFill()
            let rect = NSRect(
                origin: NSPoint(
                    x: CGFloat(index) * (Self.segment.width + Self.gap),
                    y: ((bounds.height - Self.segment.height) * Self.half).rounded()),
                size: Self.segment)
            NSBezierPath(roundedRect: rect, xRadius: Self.radius, yRadius: Self.radius).fill()
        }
    }
}
