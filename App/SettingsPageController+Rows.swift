import AppKit

extension SettingsPageController {
    static let rowPadding: CGFloat = 12
    private static let cornerRadius: CGFloat = 10

    static func box(_ views: [NSView]) -> NSView {
        let rows = NSStackView()
        rows.orientation = .vertical
        rows.spacing = 0
        rows.translatesAutoresizingMaskIntoConstraints = false
        for (index, view) in views.enumerated() {
            if index > 0 {
                rows.addArrangedSubview(separator())
            }
            rows.addArrangedSubview(view)
        }
        for row in rows.arrangedSubviews {
            row.widthAnchor.constraint(equalTo: rows.widthAnchor).isActive = true
        }
        let box = NSBox()
        box.boxType = .custom
        box.titlePosition = .noTitle
        box.cornerRadius = cornerRadius
        box.fillColor = .quaternarySystemFill
        box.borderColor = .separatorColor
        box.addSubview(rows)
        NSLayoutConstraint.activate([
            rows.topAnchor.constraint(equalTo: box.topAnchor),
            rows.bottomAnchor.constraint(equalTo: box.bottomAnchor),
            rows.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: box.trailingAnchor),
        ])
        return box
    }

    private static func separator() -> NSView {
        let line = NSBox()
        line.boxType = .separator
        let inset = NSStackView(views: [line])
        inset.edgeInsets = NSEdgeInsets(top: 0, left: rowPadding, bottom: 0, right: rowPadding)
        return inset
    }
}
