import AppKit

final class PillButton: NSButton {
    private static let titleSize: CGFloat = 13
    private static let symbolSize: CGFloat = 11
    private static let symbolGap: CGFloat = 6
    private static let padding: CGFloat = 12
    private static let pressedDarkening: CGFloat = 0.18
    private static let half: CGFloat = 0.5

    private let height: CGFloat
    private let fill: NSColor

    override var wantsUpdateLayer: Bool { true }

    override var isHighlighted: Bool {
        didSet { needsDisplay = true }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: ceil(attributedTitle.size().width) + Self.padding + Self.padding, height: height)
    }

    override var focusRingMaskBounds: NSRect { bounds }

    convenience init(_ title: String, height: CGFloat) {
        self.init(title, height: height, symbol: nil, fill: .controlAccentColor, text: .white)
    }

    init(_ title: String, height: CGFloat, symbol: String?, fill: NSColor, text: NSColor) {
        self.height = height
        self.fill = fill
        super.init(frame: .zero)
        isBordered = false
        wantsLayer = true
        let font = NSFont.systemFont(ofSize: Self.titleSize, weight: .medium)
        let label = NSMutableAttributedString(
            string: title, attributes: [.font: font, .foregroundColor: text])
        if let symbol {
            label.insert(Self.icon(symbol, colour: .secondaryLabelColor, font: font), at: 0)
            setAccessibilityLabel(title)
        }
        attributedTitle = label
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func icon(_ name: String, colour: NSColor, font: NSFont) -> NSAttributedString {
        let configuration = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .bold)
            .applying(.init(paletteColors: [colour]))
        let symbol =
            NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) ?? NSImage()
        let size = NSSize(width: symbol.size.width + symbolGap, height: symbol.size.height)
        let attachment = NSTextAttachment()
        attachment.image = NSImage(size: size, flipped: false) { _ in
            symbol.draw(in: NSRect(origin: .zero, size: symbol.size))
            return true
        }
        attachment.bounds = NSRect(
            origin: NSPoint(x: 0, y: (font.capHeight - size.height) * half), size: size)
        return NSAttributedString(attachment: attachment)
    }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let pressed = fill.blended(withFraction: Self.pressedDarkening, of: .black) ?? fill
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
