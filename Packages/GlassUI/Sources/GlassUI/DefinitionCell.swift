import AppKit

final class DefinitionCell: NSTableCellView {
    static let id = NSUserInterfaceItemIdentifier("definition")
    private static let marginTop: CGFloat = 8
    private static let margin: CGFloat = 4
    private static let paddingX: CGFloat = 18
    private static let paddingY: CGFloat = 16
    private static let radius: CGFloat = 16
    private static let gap: CGFloat = 8
    private static let headlineGap: CGFloat = 10
    private static let headwordSize: CGFloat = 26
    private static let detailSize: CGFloat = 13
    private static let textSize: CGFloat = 14
    private static let lineHeight: CGFloat = 21
    private static let maxLines = 3
    private static let labelSize: CGFloat = 12
    private static let chipGap: CGFloat = 6
    private static let labelGap: CGFloat = 8
    private static let chipHeight: CGFloat = 22
    private static let chipRadius: CGFloat = 11
    private static let chipInset: CGFloat = 9
    private static let chipSize: CGFloat = 12.5
    private static let fillAlpha = (dark: 0.06, light: 0.04)
    private static let fill = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? .white.withAlphaComponent(fillAlpha.dark)
            : .black.withAlphaComponent(fillAlpha.light)
    }
    private static let paragraph = {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = lineHeight
        style.maximumLineHeight = lineHeight
        return style
    }()
    private static let sizer = DefinitionCell()

    let card = NSBox()
    let headword = NSTextField(labelWithString: "")
    let detail = NSTextField(labelWithString: "")
    let definition = NSTextField(wrappingLabelWithString: "")
    let similar = NSStackView()
    let opposite = NSTextField(labelWithString: "")
    var onPick: ((String) -> Void)?
    private let similarLabel = NSTextField(labelWithString: "Similar")
    private var queries: [String] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        identifier = Self.id
        card.boxType = .custom
        card.cornerRadius = Self.radius
        card.fillColor = Self.fill
        card.borderColor = Self.fill
        card.borderWidth = 1
        let serif = NSFont.systemFont(ofSize: Self.headwordSize, weight: .semibold)
        headword.font = serif.fontDescriptor.withDesign(.serif).flatMap { descriptor in
            NSFont(descriptor: descriptor, size: Self.headwordSize)
        }
        detail.font = .systemFont(ofSize: Self.detailSize)
        detail.textColor = .secondaryLabelColor
        definition.maximumNumberOfLines = Self.maxLines
        definition.lineBreakMode = .byTruncatingTail
        definition.cell?.truncatesLastVisibleLine = true
        definition.heightAnchor.constraint(
            lessThanOrEqualToConstant: Self.lineHeight * CGFloat(Self.maxLines)
        ).isActive = true
        similarLabel.font = .systemFont(ofSize: Self.labelSize, weight: .semibold)
        similarLabel.textColor = .secondaryLabelColor
        similar.spacing = Self.chipGap
        similar.setClippingResistancePriority(.defaultLow, for: .horizontal)
        opposite.font = .systemFont(ofSize: Self.labelSize)
        opposite.textColor = .secondaryLabelColor
        opposite.lineBreakMode = .byTruncatingTail
        layoutCard()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    static func height(for card: ResultList.Card, width: CGFloat) -> CGFloat {
        sizer.show(card, width: width)
        return sizer.fittingSize.height
    }

    func show(_ card: ResultList.Card, width: CGFloat) {
        headword.stringValue = card.title
        detail.stringValue = card.detail
        definition.attributedStringValue = NSAttributedString(
            string: card.text,
            attributes: [
                .font: NSFont.systemFont(ofSize: Self.textSize),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: Self.paragraph,
            ])
        definition.preferredMaxLayoutWidth =
            width - Self.margin - Self.margin - Self.paddingX - Self.paddingX
        queries = card.similar.map(\.query)
        let chips = card.similar.enumerated().map { chip($0.element.title, tag: $0.offset) }
        similar.setViews([similarLabel] + chips, in: .leading)
        similar.setCustomSpacing(Self.labelGap, after: similarLabel)
        for (index, chip) in chips.enumerated() {
            similar.setVisibilityPriority(
                .init(rawValue: Float(chips.count - index)),
                for: chip)
        }
        similar.isHidden = chips.isEmpty
        opposite.stringValue = "Opposite: " + card.opposite.joined(separator: ", ")
        opposite.isHidden = card.opposite.isEmpty
    }

    @objc
    private func picked(_ chip: NSButton) {
        onPick?(queries[chip.tag])
    }

    private func chip(_ title: String, tag: Int) -> NSView {
        let button = NSButton(title: title, target: self, action: #selector(picked))
        button.isBordered = false
        button.font = .systemFont(ofSize: Self.chipSize)
        button.tag = tag
        button.refusesFirstResponder = true
        button.translatesAutoresizingMaskIntoConstraints = false
        let box = NSBox()
        box.boxType = .custom
        box.borderWidth = 0
        box.cornerRadius = Self.chipRadius
        box.fillColor = FloatingCapsule.keycapFill
        box.contentViewMargins = .zero
        box.addSubview(button)
        NSLayoutConstraint.activate([
            box.heightAnchor.constraint(equalToConstant: Self.chipHeight),
            box.widthAnchor.constraint(
                equalToConstant: button.intrinsicContentSize.width + Self.chipInset
                    + Self.chipInset),
            button.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            button.topAnchor.constraint(equalTo: box.topAnchor),
            button.bottomAnchor.constraint(equalTo: box.bottomAnchor),
        ])
        return box
    }

    private func layoutCard() {
        let headline = NSStackView(views: [headword, detail])
        headline.alignment = .firstBaseline
        headline.spacing = Self.headlineGap
        let stack = NSStackView(views: [headline, definition, similar, opposite])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.gap
        for view in [card, stack] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor, constant: Self.marginTop),
            card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.margin),
            card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.margin),
            card.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.margin),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: Self.paddingY),
            stack.bottomAnchor.constraint(
                equalTo: card.bottomAnchor, constant: -Self.paddingY),
            stack.leadingAnchor.constraint(
                equalTo: card.leadingAnchor, constant: Self.paddingX),
            stack.trailingAnchor.constraint(
                lessThanOrEqualTo: card.trailingAnchor, constant: -Self.paddingX),
            similar.trailingAnchor.constraint(
                lessThanOrEqualTo: card.trailingAnchor, constant: -Self.paddingX),
            opposite.trailingAnchor.constraint(
                lessThanOrEqualTo: card.trailingAnchor, constant: -Self.paddingX),
        ])
    }
}
