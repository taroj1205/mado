import AppKit

extension FillInForm {
    private static let labelWidth: CGFloat = 70
    private static let labelTop: CGFloat = 6
    private static let columnGap: CGFloat = 14
    private static let tileSize: CGFloat = 28
    private static let tileRadius: CGFloat = 8
    private static let tileGlyph: CGFloat = 16
    private static let tileColor = NSColor.systemPurple
    private static let headerGap: CGFloat = 10
    private static let namesGap: CGFloat = 1
    private static let titleSize: CGFloat = 14
    private static let subtitleSize: CGFloat = 12
    private static let previewSide: CGFloat = 12
    private static let previewTop: CGFloat = 10
    private static let previewLines = 6
    private static let previewRadius: CGFloat = 10
    private static let previewAlpha = (dark: 0.22, light: 0.04)
    private static let edgeAlpha = (dark: 0.06, light: 0.08)
    private static let buttonGap: CGFloat = 8
    private static let insetTop: CGFloat = 14
    private static let gap: CGFloat = 12
    private static let rowGap: CGFloat = 10

    func row(_ name: String, _ control: NSControl) -> NSView {
        let label = SheetForm.label(name, color: .secondaryLabelColor)
        label.alignment = .right
        let gutter = NSStackView(views: [label])
        gutter.orientation = .vertical
        gutter.alignment = .trailing
        gutter.edgeInsets = NSEdgeInsets(top: Self.labelTop, left: 0, bottom: 0, right: 0)
        gutter.widthAnchor.constraint(equalToConstant: Self.labelWidth).isActive = true
        let shown: NSView =
            if let input = control as? NSTextField {
                SheetForm.field(input, label: name, width: nil, font: SheetForm.font)
            } else {
                control
            }
        let row = NSStackView(views: [gutter, shown])
        row.alignment = .top
        row.spacing = Self.columnGap
        if control is NSTextField {
            shown.widthAnchor.constraint(
                equalTo: row.widthAnchor, constant: -Self.labelWidth - Self.columnGap
            ).isActive = true
        }
        return row
    }

    private func layoutHeader() -> NSView {
        let tile = NSBox()
        tile.boxType = .custom
        tile.borderWidth = 0
        tile.cornerRadius = Self.tileRadius
        tile.fillColor = Self.tileColor
        tile.contentViewMargins = .zero
        let glyph = NSImageView()
        glyph.image = NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: nil)
        glyph.symbolConfiguration = .init(pointSize: Self.tileGlyph, weight: .semibold)
        glyph.contentTintColor = .white
        tile.contentView = glyph
        tile.widthAnchor.constraint(equalToConstant: Self.tileSize).isActive = true
        tile.heightAnchor.constraint(equalToConstant: Self.tileSize).isActive = true
        title.font = .systemFont(ofSize: Self.titleSize, weight: .semibold)
        subtitle.font = .systemFont(ofSize: Self.subtitleSize)
        subtitle.textColor = .secondaryLabelColor
        let names = NSStackView(views: [title, subtitle])
        names.orientation = .vertical
        names.alignment = .leading
        names.spacing = Self.namesGap
        let header = NSStackView(views: [tile, names])
        header.spacing = Self.headerGap
        return header
    }

    func layoutForm() {
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = Self.rowGap
        let buttons = NSStackView(views: [cancel, insert])
        buttons.spacing = Self.buttonGap
        let footer = NSStackView()
        footer.setViews([buttons], in: .trailing)
        let form = NSStackView(views: [layoutHeader(), rows, layoutPreview(), footer])
        form.orientation = .vertical
        form.alignment = .leading
        form.spacing = Self.gap
        form.edgeInsets = NSEdgeInsets(
            top: Self.insetTop, left: Self.insetSide, bottom: Self.insetTop, right: Self.insetSide)
        form.translatesAutoresizingMaskIntoConstraints = false
        addSubview(form)
        for view in form.views.dropFirst() {
            view.widthAnchor.constraint(
                equalTo: form.widthAnchor, constant: -Self.insetSide - Self.insetSide
            ).isActive = true
        }
        NSLayoutConstraint.activate([
            form.leadingAnchor.constraint(equalTo: leadingAnchor),
            form.trailingAnchor.constraint(equalTo: trailingAnchor),
            form.topAnchor.constraint(equalTo: topAnchor),
            form.bottomAnchor.constraint(equalTo: bottomAnchor),
            form.widthAnchor.constraint(equalToConstant: Self.width),
        ])
    }

    private func layoutPreview() -> NSView {
        previewText.isSelectable = false
        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = Self.previewRadius
        box.borderWidth = 1
        box.fillColor = SheetForm.adaptive(
            dark: .black.withAlphaComponent(Self.previewAlpha.dark),
            light: .black.withAlphaComponent(Self.previewAlpha.light))
        box.borderColor = SheetForm.adaptive(
            dark: .white.withAlphaComponent(Self.edgeAlpha.dark),
            light: .black.withAlphaComponent(Self.edgeAlpha.light))
        box.contentViewMargins = .zero
        previewText.maximumNumberOfLines = Self.previewLines
        previewText.preferredMaxLayoutWidth =
            Self.width - Self.insetSide - Self.insetSide - Self.previewSide - Self.previewSide
        previewText.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(previewText)
        NSLayoutConstraint.activate([
            previewText.leadingAnchor.constraint(
                equalTo: box.leadingAnchor, constant: Self.previewSide),
            previewText.trailingAnchor.constraint(
                equalTo: box.trailingAnchor, constant: -Self.previewSide),
            previewText.topAnchor.constraint(equalTo: box.topAnchor, constant: Self.previewTop),
            previewText.bottomAnchor.constraint(
                equalTo: box.bottomAnchor, constant: -Self.previewTop),
        ])
        return box
    }
}
