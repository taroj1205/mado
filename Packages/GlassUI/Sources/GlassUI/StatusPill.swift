import AppKit

final class StatusPill: NSView {
    private static let height: CGFloat = 36
    private static let radius: CGFloat = 12
    private static let leading: CGFloat = 11
    private static let trailing: CGFloat = 13
    private static let gap: CGFloat = 6
    private static let fontSize: CGFloat = 13

    let icon = NSImageView()
    let label = NSTextField(labelWithString: "")
    let glass: GlassView
    private(set) var symbol: String?

    var text: String {
        label.stringValue
    }

    init() {
        icon.symbolConfiguration = .init(pointSize: Self.fontSize, weight: .medium)
        icon.contentTintColor = .secondaryLabelColor
        let stack = NSStackView(views: [icon, label])
        stack.spacing = Self.gap
        glass = FloatingCapsule.make(
            stack, leading: Self.leading, trailing: Self.trailing,
            height: Self.height, radius: Self.radius)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(glass)
        NSLayoutConstraint.activate([
            glass.leadingAnchor.constraint(equalTo: leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: trailingAnchor),
            glass.topAnchor.constraint(equalTo: topAnchor),
            glass.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    static func styled(_ text: String) -> NSAttributedString {
        let count = text.prefix(while: \.isNumber)
        let styled = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor,
            ])
        guard !count.isEmpty, text.dropFirst(count.count).first == " " else { return styled }
        styled.addAttributes(
            [
                .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
            ], range: NSRange(location: 0, length: count.utf16.count))
        return styled
    }

    func show(_ text: String?, symbol: String?) {
        isHidden = text == nil
        self.symbol = symbol
        label.attributedStringValue = Self.styled(text ?? "")
        icon.image = symbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
        icon.isHidden = icon.image == nil
    }
}
