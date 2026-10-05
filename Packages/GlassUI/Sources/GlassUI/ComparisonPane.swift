public import AppKit

final class ComparisonPane: NSView {
    static let listWidth: CGFloat = 400
    private static let top: CGFloat = 14
    private static let side: CGFloat = 18
    private static let bottom: CGFloat = 64
    private static let gap: CGFloat = 10
    private static let labelGap: CGFloat = 6
    private static let captionSize: CGFloat = 12
    private static let labelSize: CGFloat = 11.5
    private static let textSize: CGFloat = 12.5
    private static let lineHeight: CGFloat = 1.5
    private static let textLimit = 2_000
    private static let boxRadius: CGFloat = 10
    private static let boxInsetX: CGFloat = 12
    private static let boxInsetY: CGFloat = 10
    private static let half: CGFloat = 0.5
    private static let separator = " · "

    private let caption = NSTextField(labelWithString: "")
    let before = ComparisonPane.box()
    let after = ComparisonPane.box()

    override init(frame: NSRect) {
        super.init(frame: frame)
        isHidden = true
        caption.font = .systemFont(ofSize: Self.captionSize)
        caption.textColor = .secondaryLabelColor
        caption.lineBreakMode = .byTruncatingTail
        caption.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let beforeLabel = Self.label("Before")
        let afterLabel = Self.label("After")
        let stack = NSStackView(views: [caption, beforeLabel, before.box, afterLabel, after.box])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.gap
        stack.setCustomSpacing(Self.labelGap, after: beforeLabel)
        stack.setCustomSpacing(Self.labelGap, after: afterLabel)
        let texts = [caption, beforeLabel, afterLabel].map(\.intrinsicContentSize.height)
        let gaps = [Self.gap, Self.labelGap, Self.gap, Self.labelGap]
        layout(stack, reserving: (texts + gaps).reduce(Self.top + Self.bottom, +))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func label(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: labelSize, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    private static func box() -> (box: NSBox, text: NSTextField) {
        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = boxRadius
        box.borderWidth = 1
        box.fillColor = DetailPane.fill
        box.borderColor = DetailPane.edge
        box.contentViewMargins = NSSize(width: boxInsetX, height: boxInsetY)
        let content = NSView()
        content.clipsToBounds = true
        let text = NSTextField(wrappingLabelWithString: "")
        text.isSelectable = false
        text.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        text.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        text.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(text)
        NSLayoutConstraint.activate([
            text.topAnchor.constraint(equalTo: content.topAnchor),
            text.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            text.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            text.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor),
        ])
        let hug = text.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        hug.priority = .defaultHigh
        hug.isActive = true
        box.contentView = content
        return (box, text)
    }

    private static func styled(
        _ text: String, struck: IndexSet = [], color: NSColor = .labelColor
    ) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = textSize * lineHeight
        style.maximumLineHeight = style.minimumLineHeight
        let font = NSFont.monospacedSystemFont(ofSize: textSize, weight: .regular)
        let shown = NSMutableAttributedString()
        let lines = text.prefix(textLimit).split(
            omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        for (index, line) in lines.enumerated() {
            let isStruck = struck.contains(index)
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font, .paragraphStyle: style,
                .foregroundColor: isStruck ? NSColor.tertiaryLabelColor : color,
            ]
            if isStruck {
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            }
            let ending = index == lines.count - 1 ? "" : "\n"
            shown.append(NSAttributedString(string: line + ending, attributes: attributes))
        }
        return shown
    }

    private func layout(_ stack: NSStackView, reserving reserved: CGFloat) {
        let divider = NSBox()
        divider.boxType = .separator
        for view in [divider, stack] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            divider.topAnchor.constraint(equalTo: topAnchor),
            divider.bottomAnchor.constraint(equalTo: bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Self.top),
            stack.leadingAnchor.constraint(equalTo: divider.trailingAnchor, constant: Self.side),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.side),
            caption.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        for box in [before.box, after.box] {
            NSLayoutConstraint.activate([
                box.widthAnchor.constraint(equalTo: stack.widthAnchor),
                box.heightAnchor.constraint(
                    lessThanOrEqualTo: heightAnchor, multiplier: Self.half,
                    constant: -reserved * Self.half),
            ])
        }
    }

    func show(_ comparison: LauncherView.Comparison?) {
        isHidden = comparison == nil
        guard let comparison else { return }
        let lead = NSMutableAttributedString(string: comparison.source.label + " ")
        lead.append(
            NSAttributedString(
                string: comparison.source.name,
                attributes: [
                    .font: NSFont.systemFont(ofSize: Self.captionSize, weight: .semibold),
                    .foregroundColor: NSColor.labelColor,
                ]))
        lead.append(NSAttributedString(string: Self.separator + comparison.counts))
        caption.attributedStringValue = lead
        before.text.attributedStringValue = Self.styled(
            comparison.before, struck: comparison.struck)
        after.text.attributedStringValue = Self.styled(
            comparison.after, color: comparison.changes ? .labelColor : .secondaryLabelColor)
    }
}

extension LauncherView {
    public struct Comparison {
        public let source: (label: String, name: String)
        public let counts: String
        public let before: String
        public let struck: IndexSet
        public let after: String
        public let changes: Bool

        public init(
            source: (label: String, name: String), counts: String, before: String,
            struck: IndexSet, after: String, changes: Bool
        ) {
            self.source = source
            self.counts = counts
            self.before = before
            self.struck = struck
            self.after = after
            self.changes = changes
        }
    }
}
