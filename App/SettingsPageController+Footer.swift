import AppKit

extension SettingsPageController {
    private static let footerSize: CGFloat = 12

    static func footer(_ text: NSAttributedString) -> NSView {
        let label = NSTextField(wrappingLabelWithString: "")
        label.font = .systemFont(ofSize: footerSize)
        label.textColor = .secondaryLabelColor
        label.attributedStringValue = text
        label.isSelectable = true
        label.allowsEditingTextAttributes = true
        let inset = NSStackView(views: [label])
        inset.edgeInsets = NSEdgeInsets(top: 0, left: headerInset, bottom: 0, right: 0)
        return inset
    }
}
