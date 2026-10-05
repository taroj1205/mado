import AppKit

final class SettingsPageCell: NSTableCellView {
    private static let iconWidth: CGFloat = 18
    private static let iconGap: CGFloat = 9

    private let icon = NSImageView()

    var selected: Bool {
        didSet { icon.contentTintColor = selected ? .controlAccentColor : .secondaryLabelColor }
    }

    init(page: SettingsPage, selected: Bool) {
        self.selected = selected
        super.init(frame: .zero)
        icon.image = NSImage(systemSymbolName: page.symbol, accessibilityDescription: nil)
        icon.contentTintColor = selected ? .controlAccentColor : .secondaryLabelColor
        icon.widthAnchor.constraint(equalToConstant: Self.iconWidth).isActive = true
        let stack = NSStackView(views: [icon, NSTextField(labelWithString: page.title)])
        stack.spacing = Self.iconGap
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }
}
