import AppKit

final class ScopeChip: NSBox {
    private static let height: CGFloat = 28
    private static let radius: CGFloat = 14
    private static let leading: CGFloat = 8
    private static let trailing: CGFloat = 10
    private static let gap: CGFloat = 6
    private static let fontSize: CGFloat = 14

    private let icon = NSImageView()
    private let label = NSTextField(labelWithString: "")
    var onPress: (() -> Void)?

    init() {
        super.init(frame: .zero)
        boxType = .custom
        borderWidth = 0
        cornerRadius = Self.radius
        fillColor = ResultRowView.fill
        contentViewMargins = .zero
        HoverFill.install(in: self, radius: Self.radius)
        isHidden = true
        icon.symbolConfiguration = .init(pointSize: Self.fontSize, weight: .medium)
        icon.contentTintColor = .labelColor
        label.font = .systemFont(ofSize: Self.fontSize, weight: .medium)
        let stack = NSStackView(views: [icon, label])
        stack.spacing = Self.gap
        stack.edgeInsets = NSEdgeInsets(top: 0, left: Self.leading, bottom: 0, right: Self.trailing)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityHelp("Go back to search")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) ? self : nil
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

    func show(_ chip: LauncherView.Chip?) {
        isHidden = chip == nil
        label.stringValue = chip?.title ?? ""
        icon.image = chip.flatMap { shown in
            NSImage(systemSymbolName: shown.symbol, accessibilityDescription: nil)
        }
        setAccessibilityLabel(chip?.title)
    }
}
