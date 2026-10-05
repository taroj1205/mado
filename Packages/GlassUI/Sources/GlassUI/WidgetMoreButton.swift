import AppKit

final class WidgetMoreButton: NSView {
    static let size: CGFloat = 22
    private static let dot: CGFloat = 2.6
    private static let dotGap: CGFloat = 2.4
    private static let fillAlpha = (dark: 0.16, light: 0.08)
    private static let dotAlpha = (dark: 0.85, light: 0.7)
    private static let half: CGFloat = 0.5
    private static let dots = 3

    var onPress: (() -> Void)?

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.size, height: Self.size)
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.menuButton)
        setAccessibilityLabel("Widget actions")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func draw(_: NSRect) {
        WidgetTile.tone(.white, .black, Self.fillAlpha).setFill()
        NSBezierPath(ovalIn: bounds).fill()
        WidgetTile.tone(.white, .black, Self.dotAlpha).setFill()
        let span = CGFloat(Self.dots) * Self.dot + CGFloat(Self.dots - 1) * Self.dotGap
        let start = bounds.midX - span * Self.half
        for index in 0..<Self.dots {
            let left = start + CGFloat(index) * (Self.dot + Self.dotGap)
            NSBezierPath(
                ovalIn: NSRect(
                    x: left, y: bounds.midY - Self.dot * Self.half, width: Self.dot,
                    height: Self.dot)
            ).fill()
        }
    }

    override func accessibilityPerformPress() -> Bool {
        guard let onPress else { return false }
        onPress()
        return true
    }
}
