import AppKit

final class ActionRow: NSBox {
    private static let height: CGFloat = 32
    private static let radius: CGFloat = 7
    private static let leading: CGFloat = 10
    private static let trailing: CGFloat = 6
    private static let keyGap: CGFloat = 3
    private static let keyRadius: CGFloat = 5
    private static let keySize: CGFloat = 20
    private static let fontSize: CGFloat = 13
    private static let selectedKeyAlpha = 0.22

    let label: NSTextField
    let keycaps: [Keycap]
    var onPress: (() -> Void)?
    var isSelected = false {
        didSet { restyle() }
    }

    init(title text: String, keys: [String]) {
        label = NSTextField(labelWithString: text)
        keycaps = keys.map { Keycap($0, radius: Self.keyRadius, size: Self.keySize) }
        super.init(frame: .zero)
        boxType = .custom
        borderWidth = 0
        cornerRadius = Self.radius
        contentViewMargins = .zero
        label.font = .systemFont(ofSize: Self.fontSize)
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let shortcut = NSStackView(views: keycaps)
        shortcut.spacing = Self.keyGap
        for view in [label, shortcut] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.leading),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            shortcut.leadingAnchor.constraint(
                greaterThanOrEqualTo: label.trailingAnchor, constant: Self.leading),
            shortcut.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.trailing),
            shortcut.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.menuItem)
        setAccessibilityLabel(text)
        restyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with _: NSEvent) {
        onPress?()
    }

    override func accessibilityPerformPress() -> Bool {
        onPress?()
        return true
    }

    private func restyle() {
        fillColor = isSelected ? .controlAccentColor : .clear
        label.textColor = isSelected ? .white : .labelColor
        for keycap in keycaps {
            keycap.fillColor =
                isSelected
                ? .white.withAlphaComponent(Self.selectedKeyAlpha) : FloatingCapsule.keycapFill
            keycap.name.textColor = isSelected ? .white : .secondaryLabelColor
        }
        setAccessibilitySelected(isSelected)
    }
}
