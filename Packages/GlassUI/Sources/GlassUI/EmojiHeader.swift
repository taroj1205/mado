import AppKit

final class EmojiHeader: NSView, NSCollectionViewElement {
    static let id = NSUserInterfaceItemIdentifier("emojiHeader")
    private static let inset: CGFloat = 12
    private static let bottom: CGFloat = 6
    private static let fontSize: CGFloat = 12

    let label = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: Self.fontSize, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.inset),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.bottom),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }
}
