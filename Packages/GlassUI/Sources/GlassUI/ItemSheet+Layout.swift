import AppKit

extension ItemSheet {
    private static let headerHeight: CGFloat = 64
    private static let headerGap: CGFloat = 12
    private static let tileSize: CGFloat = 36
    private static let tileRadius: CGFloat = 10
    static let tileBorder: CGFloat = 0.5
    private static let tileBorderAlpha: CGFloat = 0.18
    private static let glyphSize: CGFloat = 20
    private static let titleSize: CGFloat = 17
    private static let subtitleSize: CGFloat = 12.5
    private static let titleGap: CGFloat = 2
    private static let formTop: CGFloat = 18
    private static let linkSize: CGFloat = 12.5
    private static let chipHeight: CGFloat = 24
    private static let chipLeading: CGFloat = 10
    private static let chipTrailing: CGFloat = 6
    private static let chipGap: CGFloat = 6
    private static let removeSize: CGFloat = 9
    private static let fieldWidth: CGFloat = 120
    private static let chipAlpha = (dark: 0.12, light: 0.07)
    private static let half: CGFloat = 0.5
    private static let chipFill = SheetForm.adaptive(
        dark: .white.withAlphaComponent(chipAlpha.dark),
        light: .black.withAlphaComponent(chipAlpha.light))

    func chip(_ index: Int, _ alias: String) -> NSView {
        let remove = NSButton(
            image: NSImage(systemSymbolName: "xmark", accessibilityDescription: nil) ?? NSImage(),
            target: self, action: #selector(removeAlias))
        remove.isBordered = false
        remove.tag = index
        remove.contentTintColor = .secondaryLabelColor
        remove.symbolConfiguration = .init(pointSize: Self.removeSize, weight: .bold)
        remove.setAccessibilityLabel("Remove alias \(alias)")
        let stack = NSStackView(views: [SheetForm.label(alias, color: .labelColor), remove])
        stack.spacing = Self.chipGap
        stack.setHuggingPriority(.defaultHigh, for: .horizontal)
        stack.edgeInsets = NSEdgeInsets(
            top: 0, left: Self.chipLeading, bottom: 0, right: Self.chipTrailing)
        return SheetForm.box(
            stack, height: Self.chipHeight, radius: Self.chipHeight * Self.half,
            fill: Self.chipFill, border: nil)
    }

    func layoutSheet() {
        SheetForm.place(
            layoutHeader(), height: Self.headerHeight, form: layoutForm(), top: Self.formTop,
            in: self)
        SheetForm.placeCapsules(
            contextPill,
            SheetForm.buttons(cancel, save), in: self)
    }

    private func layoutForm() -> NSStackView {
        chips.spacing = Self.chipGap
        chips.setHuggingPriority(.defaultHigh, for: .horizontal)
        clear.isBordered = false
        clear.font = .systemFont(ofSize: Self.linkSize)
        clear.contentTintColor = .controlAccentColor
        ranking.font = .systemFont(ofSize: SheetForm.fontSize)
        aliasField.placeholderString = "Add alias"
        let aliasBox = SheetForm.field(
            aliasField, label: "Add alias", width: Self.fieldWidth, font: SheetForm.font)
        let form = SheetForm.form([
            SheetForm.row("Aliases", [SheetForm.line([chips, aliasBox]), aliasHintLabel]),
            SheetForm.row("Hotkey", [SheetForm.line([hotkey, clear]), hotkeyHintLabel]),
            modeRow,
            SheetForm.row(
                "Favourite",
                [
                    SheetForm.line([
                        favourite, SheetForm.label("Show on the empty query", color: .labelColor),
                    ])
                ]),
            SheetForm.row("Ranking", [SheetForm.line([ranking, resetRanking])]),
        ])
        unsafe nextKeyView = aliasField
        unsafe aliasField.nextKeyView = hotkey
        unsafe hotkey.nextKeyView = mode
        unsafe mode.nextKeyView = favourite
        unsafe favourite.nextKeyView = resetRanking
        unsafe resetRanking.nextKeyView = aliasField
        return form
    }

    private func layoutHeader() -> NSView {
        tile.boxType = .custom
        tile.titlePosition = .noTitle
        tile.cornerRadius = Self.tileRadius
        tile.borderColor = .black.withAlphaComponent(Self.tileBorderAlpha)
        tile.contentViewMargins = .zero
        icon.symbolConfiguration = .init(pointSize: Self.glyphSize, weight: .medium)
        tile.contentView = icon
        title.font = .systemFont(ofSize: Self.titleSize, weight: .semibold)
        title.lineBreakMode = .byTruncatingTail
        subtitle.font = .systemFont(ofSize: Self.subtitleSize)
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byTruncatingMiddle
        let names = NSStackView(views: [title, subtitle])
        names.orientation = .vertical
        names.alignment = .leading
        names.spacing = Self.titleGap
        NSLayoutConstraint.activate([
            tile.widthAnchor.constraint(equalToConstant: Self.tileSize),
            tile.heightAnchor.constraint(equalToConstant: Self.tileSize),
        ])
        let header = NSStackView(views: [tile, names])
        header.spacing = Self.headerGap
        return header
    }
}
