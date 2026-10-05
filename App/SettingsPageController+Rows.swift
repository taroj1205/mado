import AppKit

extension SettingsPageController {
    private static let captionSize: CGFloat = 11
    private static let rowHeight: CGFloat = 40
    private static let iconMargin: CGFloat = 18
    private static let iconGap: CGFloat = 10
    private static let rowPadding: CGFloat = 12

    func rowView(_ row: SettingsSection.Row) -> (view: NSView, label: NSTextField) {
        row.control.setAccessibilityLabel(row.label)
        let label = NSTextField(labelWithString: row.label)
        var title: NSView = label
        if let detail = row.detail {
            let detailLabel = NSTextField(labelWithString: detail())
            detailLabel.font = .systemFont(ofSize: Self.captionSize)
            detailLabel.textColor = .secondaryLabelColor
            details.append((detailLabel, detail))
            let lines = NSStackView(views: [label, detailLabel])
            lines.orientation = .vertical
            lines.alignment = .leading
            lines.spacing = 0
            title = lines
        }
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let view = NSStackView(views: [title])
        if let example = row.example {
            let exampleLabel = NSTextField(labelWithString: example)
            exampleLabel.font = .monospacedSystemFont(ofSize: Self.captionSize, weight: .regular)
            exampleLabel.textColor = .secondaryLabelColor
            view.addArrangedSubview(exampleLabel)
        }
        view.addArrangedSubview(row.control)
        view.distribution = .fill
        view.edgeInsets = NSEdgeInsets(
            top: 0, left: Self.rowPadding, bottom: 0, right: Self.rowPadding)
        if let icon = row.icon {
            view.insertArrangedSubview(icon, at: 0)
            view.setCustomSpacing(Self.iconGap, after: icon)
        }
        let height = max(Self.rowHeight, (row.icon?.fittingSize.height ?? 0) + Self.iconMargin)
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        return (view, label)
    }

    func separator() -> NSView {
        let line = NSBox()
        line.boxType = .separator
        let inset = NSStackView(views: [line])
        inset.edgeInsets = NSEdgeInsets(
            top: 0, left: Self.rowPadding, bottom: 0, right: Self.rowPadding)
        return inset
    }
}
