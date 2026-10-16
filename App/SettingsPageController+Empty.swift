import AppKit

extension SettingsPageController {
    private static let emptyIconSize: CGFloat = 30
    private static let emptyTitleSize: CGFloat = 13
    private static let emptyDetailSize: CGFloat = 12
    private static let emptySpacing: CGFloat = 6
    private static let emptyTop: CGFloat = 96

    static func emptyState(symbol: String) -> NSView {
        let icon = NSImageView(
            image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        icon.symbolConfiguration = .init(pointSize: emptyIconSize, weight: .light)
        icon.contentTintColor = .tertiaryLabelColor
        let title = NSTextField(labelWithString: "Nothing here yet")
        title.font = .systemFont(ofSize: emptyTitleSize, weight: .semibold)
        let detail = NSTextField(labelWithString: "This page has no settings so far.")
        detail.font = .systemFont(ofSize: emptyDetailSize)
        detail.textColor = .secondaryLabelColor
        let column = NSStackView(views: [icon, title, detail])
        column.orientation = .vertical
        column.alignment = .centerX
        column.spacing = emptySpacing
        column.edgeInsets = NSEdgeInsets(top: emptyTop, left: 0, bottom: 0, right: 0)
        return column
    }
}
