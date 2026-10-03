import AppKit

final class DictationFixButton: NSButton {
    private static let height: CGFloat = 24
    private static let padding: CGFloat = 10
    private static let fontSize: CGFloat = 12
    private static let half: CGFloat = 0.5
    private static let fillAlpha = (dark: 0.14, light: 0.08)
    private static let fill = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? .white.withAlphaComponent(fillAlpha.dark)
            : .black.withAlphaComponent(fillAlpha.light)
    }

    override var wantsUpdateLayer: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: ceil(attributedTitle.size().width) + Self.padding + Self.padding,
            height: Self.height)
    }

    init(_ title: String, target: AnyObject, action: Selector) {
        super.init(frame: .zero)
        isBordered = false
        wantsLayer = true
        refusesFirstResponder = true
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: Self.fontSize),
                .foregroundColor: NSColor.labelColor,
            ])
        self.target = target
        self.action = action
        setContentHuggingPriority(.required, for: .horizontal)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = Self.fill.cgColor
        }
        layer?.cornerRadius = Self.height * Self.half
        layer?.cornerCurve = .continuous
    }
}
