import AppKit

extension QuicklinkSheet {
    private static let headerHeight: CGFloat = 60
    private static let headerGap: CGFloat = 12
    private static let headerGlyphSize: CGFloat = 20
    private static let headingSize: CGFloat = 18
    private static let formTop: CGFloat = 20
    private static let popUpWidth: CGFloat = 220
    private static let tileSize: CGFloat = 28
    private static let tileRadius: CGFloat = 8
    private static let tileBorderAlpha: CGFloat = 0.18
    private static let tileGlyphSize: CGFloat = 16
    private static let iconGap: CGFloat = 8
    private static let aliasWidth: CGFloat = 120

    private static func linkHintText() -> NSAttributedString {
        let size = SheetForm.hintSize
        let text = NSMutableAttributedString(
            string: "Put \(placeholder) where the search text should go. "
                + "Also works with folders and app deep links.",
            attributes: [
                .font: NSFont.systemFont(ofSize: size),
                .foregroundColor: NSColor.secondaryLabelColor,
            ])
        if let range = text.string.range(of: placeholder) {
            text.addAttributes(
                [.font: NSFont.boldSystemFont(ofSize: size), .foregroundColor: NSColor.labelColor],
                range: NSRange(range, in: text.string))
        }
        return text
    }

    func layoutSheet() {
        SheetForm.place(
            layoutHeader(), height: Self.headerHeight, form: layoutForm(), top: Self.formTop,
            in: self)
        SheetForm.placeCapsules(
            contextPill,
            SheetForm.buttons(cancel, save), in: self)
    }

    private func layoutHeader() -> NSView {
        let glyph = NSImageView()
        glyph.image = NSImage(systemSymbolName: Self.symbol, accessibilityDescription: nil)
        glyph.symbolConfiguration = .init(pointSize: Self.headerGlyphSize, weight: .regular)
        glyph.contentTintColor = .secondaryLabelColor
        heading.font = .systemFont(ofSize: Self.headingSize, weight: .semibold)
        let header = NSStackView(views: [glyph, heading])
        header.spacing = Self.headerGap
        return header
    }

    private func layoutForm() -> NSStackView {
        linkField.placeholderString = "https://example.com/search?q=\(Self.placeholder)"
        linkHint.attributedStringValue = Self.linkHintText()
        openWith.font = SheetForm.font
        openWith.setAccessibilityLabel("Open with")
        openWith.widthAnchor.constraint(equalToConstant: Self.popUpWidth).isActive = true
        let iconLine = SheetForm.line([layoutTile(), useWebsiteIcon])
        iconLine.spacing = Self.iconGap
        let mono = NSFont.monospacedSystemFont(ofSize: SheetForm.fontSize, weight: .regular)
        let name = SheetForm.field(nameField, label: "Name", width: nil, font: SheetForm.font)
        let link = SheetForm.field(linkField, label: "Link", width: nil, font: mono)
        let alias = SheetForm.field(
            aliasField, label: "Alias", width: Self.aliasWidth, font: SheetForm.font)
        let form = SheetForm.form([
            SheetForm.row("Name", [name]),
            SheetForm.row("Link", [link, linkHint]),
            SheetForm.row("Open with", [openWith]),
            SheetForm.row("Icon", [iconLine]),
            SheetForm.row("Alias", [SheetForm.line([alias]), aliasHint]),
            SheetForm.row("Hotkey", [SheetForm.line([hotkey]), problemLabel]),
        ])
        problemLabel.textColor = .systemOrange
        problemLabel.isHidden = true
        unsafe nextKeyView = nameField
        unsafe nameField.nextKeyView = linkField
        unsafe linkField.nextKeyView = openWith
        unsafe openWith.nextKeyView = useWebsiteIcon
        unsafe useWebsiteIcon.nextKeyView = aliasField
        unsafe aliasField.nextKeyView = hotkey
        unsafe hotkey.nextKeyView = nameField
        return form
    }

    private func layoutTile() -> NSView {
        tile.boxType = .custom
        tile.titlePosition = .noTitle
        tile.cornerRadius = Self.tileRadius
        tile.borderColor = .black.withAlphaComponent(Self.tileBorderAlpha)
        tile.contentViewMargins = .zero
        tileIcon.symbolConfiguration = .init(pointSize: Self.tileGlyphSize, weight: .medium)
        tileIcon.contentTintColor = .labelColor
        tile.contentView = tileIcon
        NSLayoutConstraint.activate([
            tile.widthAnchor.constraint(equalToConstant: Self.tileSize),
            tile.heightAnchor.constraint(equalToConstant: Self.tileSize),
        ])
        return tile
    }
}
