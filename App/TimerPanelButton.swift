import AppKit

final class TimerPanelButton: NSButton {
    private static let height: CGFloat = 30
    private static let side: CGFloat = 12
    private static let fontSize: CGFloat = 13
    private static let fill: CGFloat = 0.10
    private static let half: CGFloat = 0.5

    private let isPrimary: Bool
    private let onPress: () -> Void

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: attributedTitle.size().width.rounded(.up) + Self.side + Self.side,
            height: Self.height)
    }

    init(_ title: String, isPrimary: Bool, onPress: @escaping () -> Void) {
        self.isPrimary = isPrimary
        self.onPress = onPress
        super.init(frame: .zero)
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: Self.fontSize, weight: .medium),
                .foregroundColor: isPrimary ? NSColor.white : NSColor.labelColor,
            ])
        isBordered = false
        refusesFirstResponder = true
        wantsLayer = true
        layer?.cornerRadius = Self.height * Self.half
        target = self
        action = #selector(pressed)
        tint()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        tint()
    }

    private func tint() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor =
                (isPrimary
                ? NSColor.controlAccentColor : NSColor.labelColor.withAlphaComponent(Self.fill))
                .cgColor
        }
    }

    @objc
    private func pressed() {
        onPress()
    }
}
