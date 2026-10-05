import AppKit

final class TimerPanelRow: NSView {
    private static let height: CGFloat = 24
    private static let labelWidth: CGFloat = 250
    private static let gap: CGFloat = 8
    private static let iconSize: CGFloat = 13
    private static let textSize: CGFloat = 13
    private static let hintSize: CGFloat = 12.5

    private let time = NSTextField(labelWithString: "")
    private let name: String
    private let onPress: () -> Void

    init(symbol: String, text: String, isHint: Bool, onPress: @escaping () -> Void) {
        self.onPress = onPress
        name = text
        super.init(frame: .zero)
        let icon = NSImageView(
            image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        icon.symbolConfiguration = .init(pointSize: Self.iconSize, weight: .regular)
        icon.contentTintColor = .secondaryLabelColor
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: isHint ? Self.hintSize : Self.textSize)
        label.textColor = isHint ? .secondaryLabelColor : .labelColor
        if isHint {
            label.lineBreakMode = .byWordWrapping
            label.maximumNumberOfLines = 0
            label.preferredMaxLayoutWidth = Self.labelWidth
        } else {
            label.lineBreakMode = .byTruncatingTail
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        time.font = .monospacedDigitSystemFont(ofSize: Self.textSize, weight: .regular)
        time.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [icon, label, NSView(), time])
        stack.spacing = Self.gap
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: Self.height),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(text)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func show(time text: String) {
        time.stringValue = text
        setAccessibilityLabel("\(name), \(text)")
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with _: NSEvent) {
        onPress()
    }

    override func accessibilityPerformPress() -> Bool {
        onPress()
        return true
    }
}
