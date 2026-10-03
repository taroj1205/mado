import AppKit

final class ChipButton: NSButton {
    private static let height: CGFloat = 24
    private static let side: CGFloat = 10
    private static let fontSize: CGFloat = 12
    private static let half: CGFloat = 0.5
    private static let fillAlpha = (dark: 0.14, light: 0.08)
    private static let fill = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? .white.withAlphaComponent(fillAlpha.dark)
            : .black.withAlphaComponent(fillAlpha.light)
    }

    var onPress: (() -> Void)?

    override var title: String {
        didSet {
            attributedTitle = NSAttributedString(
                string: title,
                attributes: [
                    .font: NSFont.systemFont(ofSize: Self.fontSize),
                    .foregroundColor: NSColor.labelColor,
                ])
        }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: attributedTitle.size().width.rounded(.up) + Self.side + Self.side,
            height: Self.height)
    }

    init() {
        super.init(frame: .zero)
        isBordered = false
        target = self
        action = #selector(press)
        setContentHuggingPriority(.required, for: .horizontal)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        Self.fill.setFill()
        let radius = bounds.height * Self.half
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()
        super.draw(dirtyRect)
    }

    @objc
    private func press() {
        onPress?()
    }
}
