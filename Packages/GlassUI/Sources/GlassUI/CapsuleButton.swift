import AppKit

final class CapsuleButton: NSBox {
    private static let gap: CGFloat = 8
    private static let iconGap: CGFloat = 7
    private static let keyGap: CGFloat = 3
    private static let leading: CGFloat = 12
    private static let symbolLeading: CGFloat = 10
    private static let trailing: CGFloat = 5
    static let standardHeight: CGFloat = 30
    private static let radius: CGFloat = 9
    private static let symbolSize: CGFloat = 13
    private static let accentKeyRadius: CGFloat = 10
    private static let accentKeyAlpha: CGFloat = 0.22
    private static let accentFontSize: CGFloat = 13
    private static let half: CGFloat = 0.5

    let label = FloatingCapsule.label(weight: .medium, color: .labelColor)
    let icon = NSImageView()
    let keycaps: NSStackView
    var onPress: (() -> Void)?

    convenience init(_ title: String, keys: [String]) {
        self.init(title, keys: keys, symbol: nil, height: Self.standardHeight)
    }

    init(_ title: String, keys: [String], symbol: String?, height: CGFloat) {
        keycaps = NSStackView(views: keys.map(FloatingCapsule.keycap))
        super.init(frame: .zero)
        label.stringValue = title
        keycaps.spacing = Self.keyGap
        icon.image = symbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
        icon.symbolConfiguration = .init(pointSize: Self.symbolSize, weight: .medium)
        icon.contentTintColor = .labelColor
        icon.isHidden = symbol == nil
        let stack = NSStackView(views: [icon, label, keycaps])
        stack.spacing = Self.gap
        stack.setCustomSpacing(Self.iconGap, after: icon)
        let inset = symbol == nil ? Self.leading : Self.symbolLeading
        stack.edgeInsets = NSEdgeInsets(
            top: 0, left: inset, bottom: 0, right: keys.isEmpty ? inset : Self.trailing)
        stack.translatesAutoresizingMaskIntoConstraints = false
        boxType = .custom
        borderWidth = 0
        cornerRadius = Self.radius
        fillColor = .clear
        contentViewMargins = .zero
        addSubview(stack)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: height),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(title)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    static func accent(_ title: String, keys: [String], height: CGFloat) -> CapsuleButton {
        let button = CapsuleButton(title, keys: keys, symbol: nil, height: height)
        button.fillColor = .controlAccentColor
        button.cornerRadius = height * half
        button.label.textColor = .white
        button.label.font = .systemFont(ofSize: accentFontSize, weight: .semibold)
        for case let key as Keycap in button.keycaps.arrangedSubviews {
            key.cornerRadius = accentKeyRadius
            key.fillColor = .white.withAlphaComponent(accentKeyAlpha)
            key.name.textColor = .white
        }
        return button
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with _: NSEvent) {
        onPress?()
    }

    override func accessibilityPerformPress() -> Bool {
        onPress?()
        return onPress != nil
    }
}
