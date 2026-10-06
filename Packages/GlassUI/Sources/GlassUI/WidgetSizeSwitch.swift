import AppKit

final class WidgetSizeSwitch: NSBox {
    struct Option: Equatable {
        let size: WidgetGrid.Size
        let title: String
    }

    private static let placeholder = "square"
    private static let height: CGFloat = 24
    private static let inset: CGFloat = 2
    private static let radius: CGFloat = 9
    private static let cell: CGFloat = 5
    private static let glyphRadius: CGFloat = 2.5
    private static let onAlpha = (dark: 0.16, light: 0.9)
    private static let offAlpha = (dark: 0.07, light: 0.06)

    private let stack = NSStackView()
    var onPick: ((WidgetGrid.Size) -> Void)?
    var buttons: [CapsuleButton] { stack.arrangedSubviews.compactMap { $0 as? CapsuleButton } }

    init() {
        super.init(frame: .zero)
        boxType = .custom
        borderWidth = 0
        cornerRadius = Self.radius
        contentViewMargins = .zero
        fillColor = WidgetTile.tone(.white, .black, Self.offAlpha)
        stack.spacing = Self.inset
        stack.edgeInsets = NSEdgeInsets(
            top: Self.inset, left: Self.inset, bottom: Self.inset, right: Self.inset)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func glyph(of size: WidgetGrid.Size) -> NSImage {
        let image = NSImage(
            size: NSSize(
                width: CGFloat(size.columns) * cell, height: CGFloat(size.rows) * cell),
            flipped: false
        ) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: glyphRadius, yRadius: glyphRadius).fill()
            return true
        }
        image.isTemplate = true
        return image
    }

    func show(_ options: [Option], current: WidgetGrid.Size) {
        stack.setViews(
            options.map { option in
                let isCurrent = option.size == current
                let button = CapsuleButton(
                    option.title, keys: [], symbol: Self.placeholder, height: Self.height)
                button.cornerRadius = Self.radius - Self.inset
                button.fillColor =
                    isCurrent ? WidgetTile.tone(.white, .white, Self.onAlpha) : .clear
                button.icon.image = Self.glyph(of: option.size)
                button.icon.contentTintColor =
                    isCurrent ? .controlAccentColor : .tertiaryLabelColor
                button.setAccessibilityValue(isCurrent)
                button.onPress = { [weak self] in self?.onPick?(option.size) }
                return button
            }, in: .leading)
    }
}
