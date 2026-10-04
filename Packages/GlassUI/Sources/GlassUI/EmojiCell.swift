import AppKit

final class EmojiCell: NSCollectionViewItem {
    final class Face: NSView {
        var onPress: (() -> Void)?

        override func accessibilityPerformPress() -> Bool {
            onPress?()
            return onPress != nil
        }
    }

    static let id = NSUserInterfaceItemIdentifier("emoji")
    private static let glyphSize: CGFloat = 28
    private static let radius: CGFloat = 12
    private static let ring: CGFloat = 1.5

    private let glyph = NSTextField(labelWithString: "")
    private let backdrop = NSBox()
    private let face = Face()

    var onPress: (() -> Void)? {
        get { face.onPress }
        set { face.onPress = newValue }
    }

    override var isSelected: Bool {
        didSet { backdrop.isHidden = !isSelected }
    }

    override func loadView() {
        let cell = face
        backdrop.boxType = .custom
        backdrop.cornerRadius = Self.radius
        backdrop.borderWidth = Self.ring
        backdrop.borderColor = .controlAccentColor
        backdrop.fillColor = ResultRowView.fill
        backdrop.isHidden = true
        glyph.font = .systemFont(ofSize: Self.glyphSize)
        glyph.alignment = .center
        for view in [backdrop, glyph] {
            view.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(view)
        }
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: cell.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: cell.bottomAnchor),
            glyph.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
            glyph.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        cell.setAccessibilityElement(true)
        cell.setAccessibilityRole(.button)
        view = cell
    }

    func show(_ item: ResultList.Item) {
        glyph.stringValue = item.glyph ?? ""
        view.setAccessibilityLabel(item.title)
    }
}
