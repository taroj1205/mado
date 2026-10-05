import AppKit
import SearchKit

final class SettingsGroupCell: NSTableCellView {
    static let height: CGFloat = 24
    static let gap: CGFloat = 8
    private static let size: CGFloat = 11
    private static let iconSize: CGFloat = 11
    private static let leading: CGFloat = 8
    private static let iconGap: CGFloat = 7

    private let icon = NSImageView()
    private let title = NSTextField(labelWithString: "")
    private let clear = NSButton(title: "Clear", target: nil, action: nil)
    private var text = SettingsSearch.Text(string: "", matches: [])

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet { render() }
    }

    init(clearTarget: AnyObject?, clearAction: Selector?) {
        super.init(frame: .zero)
        icon.symbolConfiguration = .init(pointSize: Self.iconSize, weight: .semibold)
        title.lineBreakMode = .byTruncatingTail
        clear.isBordered = false
        clear.font = .systemFont(ofSize: Self.size)
        clear.contentTintColor = .secondaryLabelColor
        clear.target = clearTarget
        clear.action = clearAction
        let row = NSStackView(views: [icon, title, NSView(), clear])
        row.spacing = Self.iconGap
        row.translatesAutoresizingMaskIntoConstraints = false
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.leading),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.leading),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.heightAnchor.constraint(equalToConstant: Self.height),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func show(_ text: SettingsSearch.Text, symbol: String, clearable: Bool) {
        self.text = text
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        clear.isHidden = !clearable
        setAccessibilityLabel(text.string)
        render()
    }

    private func render() {
        let selected = backgroundStyle == .emphasized
        let dim: NSColor = selected ? .white : .secondaryLabelColor
        icon.contentTintColor = dim
        title.attributedStringValue = SidebarText.styled(
            text, size: Self.size, color: dim, matchColor: selected ? .white : .labelColor,
            weight: .semibold)
    }
}
