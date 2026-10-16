import AppKit

@MainActor
enum SettingsListRow {
    struct Entry {
        let name: String
        let key: String
        let icon: NSImage
        let detail: String?
    }

    private static let iconSize: CGFloat = 24
    private static let removeSize: CGFloat = 20

    static func addButton(
        _ title: String, enabled: Bool, target: AnyObject, action: Selector
    ) -> NSButton {
        let button = NSButton(
            title: title,
            image: NSImage(systemSymbolName: "plus", accessibilityDescription: nil) ?? NSImage(),
            target: target, action: action)
        button.imagePosition = .imageLeading
        button.isEnabled = enabled
        return button
    }

    static func make(
        _ entry: Entry, enabled: Bool, removing target: AnyObject, action: Selector
    ) -> SettingsSection.Row {
        let removeButton = NSButton(
            image: NSImage(systemSymbolName: "minus", accessibilityDescription: nil) ?? NSImage(),
            target: target, action: action)
        removeButton.isBordered = false
        removeButton.contentTintColor = .secondaryLabelColor
        removeButton.symbolConfiguration = .init(pointSize: removeSize, weight: .medium)
        removeButton.identifier = NSUserInterfaceItemIdentifier(entry.key)
        removeButton.setAccessibilityLabel("Remove \(entry.name)")
        removeButton.isEnabled = enabled
        let control = NSStackView(views: [removeButton])
        control.setHuggingPriority(.defaultHigh, for: .horizontal)
        let iconView = NSImageView(image: entry.icon)
        iconView.widthAnchor.constraint(equalToConstant: iconSize).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: iconSize).isActive = true
        var row = SettingsSection.Row(
            entry.name, control, icon: iconView, detail: entry.detail.map { detail in { detail } })
        row.key = entry.key
        return row
    }
}
