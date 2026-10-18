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

    static func iconButton(
        _ symbol: String, label: String, key: String, target: AnyObject, action: Selector
    ) -> NSButton {
        let button = NSButton(
            image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage(),
            target: target, action: action)
        button.isBordered = false
        button.contentTintColor = .secondaryLabelColor
        button.symbolConfiguration = .init(pointSize: removeSize, weight: .medium)
        button.identifier = NSUserInterfaceItemIdentifier(key)
        button.setAccessibilityLabel(label)
        return button
    }

    static func make(
        _ entry: Entry, enabled: Bool, removing target: AnyObject, action: Selector
    ) -> SettingsSection.Row {
        make(entry, enabled: enabled, removing: target, action: action, beforeRemove: [])
    }

    static func make(
        _ entry: Entry, enabled: Bool, removing target: AnyObject, action: Selector,
        beforeRemove extra: [NSButton]
    ) -> SettingsSection.Row {
        let removeButton = iconButton(
            "minus", label: "Remove \(entry.name)", key: entry.key, target: target, action: action)
        let control = NSStackView(views: extra + [removeButton])
        control.setHuggingPriority(.defaultHigh, for: .horizontal)
        for button in control.arrangedSubviews.compactMap({ $0 as? NSButton }) {
            button.isEnabled = enabled && button.isEnabled
        }
        let iconView = NSImageView(image: entry.icon)
        iconView.widthAnchor.constraint(equalToConstant: iconSize).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: iconSize).isActive = true
        var row = SettingsSection.Row(
            entry.name, control, icon: iconView, detail: entry.detail.map { detail in { detail } })
        row.key = entry.key
        return row
    }
}
