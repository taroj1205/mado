import AppKit

final class GlyphCell: NSTableCellView {
    static let id = NSUserInterfaceItemIdentifier("glyph")
    private static let glyphSize: CGFloat = 16
    private static let symbolSize: CGFloat = 13
    private static let inset: CGFloat = 10
    private static let gap: CGFloat = 10
    private static let titleSize: CGFloat = 13

    let glyph = NSImageView()
    let title = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        identifier = Self.id
        glyph.symbolConfiguration = .init(pointSize: Self.symbolSize, weight: .medium)
        title.font = .systemFont(ofSize: Self.titleSize)
        title.lineBreakMode = .byTruncatingTail
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setAccessibilityChildren([])
        for view in [glyph, title] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
            view.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        }
        NSLayoutConstraint.activate([
            glyph.widthAnchor.constraint(equalToConstant: Self.glyphSize),
            glyph.heightAnchor.constraint(equalToConstant: Self.glyphSize),
            glyph.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.inset),
            title.leadingAnchor.constraint(equalTo: glyph.trailingAnchor, constant: Self.gap),
            title.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor, constant: -Self.inset),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func show(_ item: ResultList.Item) {
        glyph.image = NSImage(systemSymbolName: item.symbol, accessibilityDescription: nil)
        glyph.contentTintColor = item.tint ?? .secondaryLabelColor
        title.stringValue = item.title
        setAccessibilityLabel(
            [item.title, item.kind].filter { !$0.isEmpty }.joined(separator: ", "))
    }
}
