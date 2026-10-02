import AppKit

final class WidgetGalleryCard: NSView {
    private static let radius: CGFloat = 16
    private static let padding: CGFloat = 12
    private static let gap: CGFloat = 8
    private static let textGap: CGFloat = 2
    private static let iconSide: CGFloat = 32
    private static let iconRadius: CGFloat = 9
    private static let iconEdge: CGFloat = 0.5
    private static let iconEdgeAlpha = 0.18
    private static let glyphSize: CGFloat = 15
    private static let checkSize: CGFloat = 11
    private static let badgeGap: CGFloat = 4
    private static let nameSize: CGFloat = 13.5
    private static let summarySize: CGFloat = 12
    private static let badgeSize: CGFloat = 12
    private static let sizeSize: CGFloat = 11

    let card: WidgetGallery.Card
    let add = NSButton(title: "Add", target: nil, action: nil)
    let added = NSStackView()
    var onAdd: (() -> Void)?

    var isAdded = false {
        didSet {
            add.isHidden = isAdded
            added.isHidden = !isAdded
        }
    }

    init(_ card: WidgetGallery.Card) {
        self.card = card
        super.init(frame: .zero)
        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = Self.radius
        box.borderWidth = 1
        box.fillColor = WidgetTile.fill
        box.borderColor = WidgetTile.edge
        box.autoresizingMask = [.width, .height]
        addSubview(box)
        let lines = NSStackView(views: [
            Self.label(card.name, size: Self.nameSize, color: .labelColor, weight: .semibold),
            Self.label(card.summary, size: Self.summarySize, color: .secondaryLabelColor),
        ])
        lines.orientation = .vertical
        lines.alignment = .leading
        lines.spacing = Self.textGap
        let header = top()
        let stack = NSStackView(views: [
            header, lines,
            Self.label(card.size.title, size: Self.sizeSize, color: .tertiaryLabelColor),
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.gap
        stack.edgeInsets = NSEdgeInsets(
            top: Self.padding, left: Self.padding, bottom: Self.padding, right: Self.padding)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            header.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.padding),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(card.name)
        isAdded = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func label(
        _ text: String, size: CGFloat, color: NSColor, weight: NSFont.Weight = .regular
    ) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    private func top() -> NSView {
        let icon = NSBox()
        icon.boxType = .custom
        icon.cornerRadius = Self.iconRadius
        icon.borderWidth = Self.iconEdge
        icon.borderColor = .black.withAlphaComponent(Self.iconEdgeAlpha)
        icon.fillColor = card.colour
        icon.contentViewMargins = .zero
        let glyph = NSImageView()
        glyph.image = NSImage(systemSymbolName: card.symbol, accessibilityDescription: nil)
        glyph.symbolConfiguration = .init(pointSize: Self.glyphSize, weight: .medium)
        glyph.contentTintColor = .white
        icon.contentView = glyph
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: Self.iconSide),
            icon.heightAnchor.constraint(equalToConstant: Self.iconSide),
        ])
        let check = NSImageView()
        check.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)
        check.symbolConfiguration = .init(pointSize: Self.checkSize, weight: .bold)
        check.contentTintColor = .systemGreen
        let badge = Self.label(
            "Added", size: Self.badgeSize, color: .systemGreen, weight: .semibold)
        added.setViews([check, badge], in: .leading)
        added.spacing = Self.badgeGap
        add.bezelStyle = .push
        add.bezelColor = .controlAccentColor
        add.target = self
        add.action = #selector(pressed)
        add.setAccessibilityLabel("Add \(card.name)")
        let row = NSStackView(views: [icon, NSView(), add, added])
        row.distribution = .fill
        return row
    }

    @objc
    private func pressed() {
        onAdd?()
    }
}
