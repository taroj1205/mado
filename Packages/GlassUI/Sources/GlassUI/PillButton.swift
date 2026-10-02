import AppKit

final class PillButton: NSButton {
    private static let titleSize: CGFloat = 13
    private static let padding: CGFloat = 12
    private static let pressedDarkening: CGFloat = 0.18
    private static let half: CGFloat = 0.5

    private let height: CGFloat

    override var wantsUpdateLayer: Bool { true }

    override var isHighlighted: Bool {
        didSet { needsDisplay = true }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: ceil(attributedTitle.size().width) + Self.padding + Self.padding, height: height)
    }

    override var focusRingMaskBounds: NSRect { bounds }

    init(_ title: String, height: CGFloat) {
        self.height = height
        super.init(frame: .zero)
        isBordered = false
        wantsLayer = true
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: Self.titleSize, weight: .medium),
                .foregroundColor: NSColor.white,
            ])
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func updateLayer() {
        let fill = NSColor.controlAccentColor
        let pressed = fill.blended(withFraction: Self.pressedDarkening, of: .black) ?? fill
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = (isHighlighted ? pressed : fill).cgColor
        }
        layer?.cornerRadius = bounds.height * Self.half
        layer?.cornerCurve = .continuous
    }

    override func drawFocusRingMask() {
        let radius = bounds.height * Self.half
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()
    }
}
