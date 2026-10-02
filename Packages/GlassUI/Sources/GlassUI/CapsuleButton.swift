import AppKit

final class CapsuleButton: NSBox {
    private static let gap: CGFloat = 8
    private static let keyGap: CGFloat = 3
    private static let leading: CGFloat = 12
    private static let trailing: CGFloat = 5
    private static let height: CGFloat = 30
    private static let radius: CGFloat = 9

    var onPress: (() -> Void)?

    init(_ title: String, keys: [String]) {
        super.init(frame: .zero)
        let label = FloatingCapsule.label(weight: .medium, color: .labelColor)
        label.stringValue = title
        let keycaps = NSStackView(views: keys.map(FloatingCapsule.keycap))
        keycaps.spacing = Self.keyGap
        let stack = NSStackView(views: [label, keycaps])
        stack.spacing = Self.gap
        stack.edgeInsets = NSEdgeInsets(top: 0, left: Self.leading, bottom: 0, right: Self.trailing)
        stack.translatesAutoresizingMaskIntoConstraints = false
        boxType = .custom
        borderWidth = 0
        cornerRadius = Self.radius
        fillColor = .clear
        contentViewMargins = .zero
        addSubview(stack)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),
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
