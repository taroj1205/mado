import AppKit

final class ChipButton: NSButton {
    static let fontSize: CGFloat = 12
    static let height: CGFloat = 24
    private static let side: CGFloat = 10
    private static let symbolGap: CGFloat = 6
    private static let half: CGFloat = 0.5
    private static let fillAlpha = (dark: 0.14, light: 0.08)
    private static let fill = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? .white.withAlphaComponent(fillAlpha.dark)
            : .black.withAlphaComponent(fillAlpha.light)
    }

    var onPress: (() -> Void)?
    private let titleFont: NSFont
    private let height: CGFloat

    override var title: String {
        didSet { paintTitle() }
    }

    var isOn = true {
        didSet {
            paintTitle()
            setAccessibilitySelected(isOn)
            needsDisplay = true
        }
    }

    override var intrinsicContentSize: NSSize {
        let symbol = image.map { $0.size.width + Self.symbolGap } ?? 0
        return NSSize(
            width: attributedTitle.size().width.rounded(.up) + symbol + Self.side + Self.side,
            height: height)
    }

    convenience init() {
        self.init(font: .systemFont(ofSize: Self.fontSize), height: Self.height, symbol: nil)
    }

    init(font: NSFont, height: CGFloat, symbol: String?) {
        titleFont = font
        self.height = height
        super.init(frame: .zero)
        isBordered = false
        target = self
        action = #selector(press)
        if let symbol {
            image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            symbolConfiguration = .init(pointSize: titleFont.pointSize, weight: .semibold)
            imagePosition = .imageLeading
            contentTintColor = .labelColor
        }
        setContentHuggingPriority(.required, for: .horizontal)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    private func paintTitle() {
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: titleFont,
                .foregroundColor: isOn ? NSColor.labelColor : .secondaryLabelColor,
            ])
    }

    override func draw(_ dirtyRect: NSRect) {
        if isOn {
            Self.fill.setFill()
            let radius = bounds.height * Self.half
            NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()
        }
        super.draw(dirtyRect)
    }

    @objc
    private func press() {
        onPress?()
    }
}
