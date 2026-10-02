import AppKit

extension ItemSheet {
    private static let headerHeight: CGFloat = 64
    private static let headerInset: CGFloat = 20
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
    private static let formLeading: CGFloat = 10
    private static let formTrailing: CGFloat = 40
    private static let rowGap: CGFloat = 14
    private static let labelWidth: CGFloat = 130
    private static let labelTop: CGFloat = 6
    private static let columnGap: CGFloat = 14
    private static let lineGap: CGFloat = 6
    private static let controlGap: CGFloat = 10
    private static let fontSize: CGFloat = 13
    private static let hintSize: CGFloat = 12
    private static let linkSize: CGFloat = 12.5
    private static let chipHeight: CGFloat = 24
    private static let chipLeading: CGFloat = 10
    private static let chipTrailing: CGFloat = 6
    private static let chipGap: CGFloat = 6
    private static let removeSize: CGFloat = 9
    private static let fieldWidth: CGFloat = 120
    private static let fieldHeight: CGFloat = 28
    private static let fieldRadius: CGFloat = 8
    private static let fieldInset: CGFloat = 10
    private static let chipAlpha = (dark: 0.12, light: 0.07)
    private static let fieldAlpha = (dark: 0.20, light: 0.05)
    private static let fieldBorderAlpha = (dark: 0.10, light: 0.12)
    private static let half: CGFloat = 0.5
    private static let capsuleInset: CGFloat = 10
    private static let contextLeading: CGFloat = 11
    private static let contextTrailing: CGFloat = 16
    private static let contextGap: CGFloat = 8
    private static let buttonsInset: CGFloat = 5
    private static let buttonsGap: CGFloat = 6
    private static let chipFill = adaptive(
        dark: .white.withAlphaComponent(chipAlpha.dark),
        light: .black.withAlphaComponent(chipAlpha.light))
    private static let fieldFill = adaptive(
        dark: .black.withAlphaComponent(fieldAlpha.dark),
        light: .black.withAlphaComponent(fieldAlpha.light))
    private static let fieldBorder = adaptive(
        dark: .white.withAlphaComponent(fieldBorderAlpha.dark),
        light: .black.withAlphaComponent(fieldBorderAlpha.light))

    private static func adaptive(dark: NSColor, light: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
    }

    static func hint() -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: "")
        label.font = .systemFont(ofSize: hintSize)
        label.textColor = .secondaryLabelColor
        return label
    }

    private static func label(_ text: String, color: NSColor = .labelColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: fontSize)
        label.textColor = color
        return label
    }

    private static func line(_ views: [NSView]) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.spacing = controlGap
        stack.setHuggingPriority(.defaultHigh, for: .horizontal)
        return stack
    }

    private static func box(
        _ content: NSView, height: CGFloat, radius: CGFloat, fill: NSColor,
        border: NSColor? = nil
    ) -> NSBox {
        let box = NSBox()
        box.boxType = .custom
        box.titlePosition = .noTitle
        box.cornerRadius = radius
        box.fillColor = fill
        box.borderColor = border ?? .clear
        box.borderWidth = border == nil ? 0 : 1
        box.contentViewMargins = .zero
        content.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(content)
        NSLayoutConstraint.activate([
            box.heightAnchor.constraint(equalToConstant: height),
            content.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            content.centerYAnchor.constraint(equalTo: box.centerYAnchor),
        ])
        return box
    }

    func chip(_ index: Int, _ alias: String) -> NSView {
        let remove = NSButton(
            image: NSImage(systemSymbolName: "xmark", accessibilityDescription: nil) ?? NSImage(),
            target: self, action: #selector(removeAlias))
        remove.isBordered = false
        remove.tag = index
        remove.contentTintColor = .secondaryLabelColor
        remove.symbolConfiguration = .init(pointSize: Self.removeSize, weight: .bold)
        remove.setAccessibilityLabel("Remove alias \(alias)")
        let stack = NSStackView(views: [Self.label(alias), remove])
        stack.spacing = Self.chipGap
        stack.setHuggingPriority(.defaultHigh, for: .horizontal)
        stack.edgeInsets = NSEdgeInsets(
            top: 0, left: Self.chipLeading, bottom: 0, right: Self.chipTrailing)
        return Self.box(
            stack, height: Self.chipHeight, radius: Self.chipHeight * Self.half,
            fill: Self.chipFill)
    }

    func layoutSheet() {
        let separator = NSBox()
        separator.boxType = .separator
        let header = layoutHeader()
        let form = layoutForm()
        let buttons = layoutButtons()
        for view in [header, separator, form, contextPill, buttons] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.headerInset),
            header.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor, constant: -Self.headerInset),
            header.centerYAnchor.constraint(
                equalTo: topAnchor, constant: Self.headerHeight * Self.half),
            separator.topAnchor.constraint(equalTo: topAnchor, constant: Self.headerHeight),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            form.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: Self.formTop),
            form.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.formLeading),
            form.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.formTrailing),
            contextPill.leadingAnchor.constraint(
                equalTo: leadingAnchor, constant: Self.capsuleInset),
            contextPill.centerYAnchor.constraint(equalTo: buttons.centerYAnchor),
            buttons.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -Self.capsuleInset),
            buttons.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.capsuleInset),
        ])
    }

    private func layoutForm() -> NSStackView {
        chips.spacing = Self.chipGap
        chips.setHuggingPriority(.defaultHigh, for: .horizontal)
        clear.isBordered = false
        clear.font = .systemFont(ofSize: Self.linkSize)
        clear.contentTintColor = .controlAccentColor
        ranking.font = .systemFont(ofSize: Self.fontSize)
        let form = NSStackView(views: [
            row("Aliases", [Self.line([chips, aliasBox()]), aliasHintLabel]),
            row("Hotkey", [Self.line([hotkey, clear]), hotkeyHintLabel]),
            modeRow,
            row("Favourite", [Self.line([favourite, Self.label("Show on the empty query")])]),
            row("Ranking", [Self.line([ranking, resetRanking])]),
        ])
        form.orientation = .vertical
        form.alignment = .leading
        form.spacing = Self.rowGap
        for row in form.arrangedSubviews {
            row.widthAnchor.constraint(equalTo: form.widthAnchor).isActive = true
        }
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

    func row(_ name: String, _ lines: [NSView]) -> NSView {
        let label = Self.label(name, color: .secondaryLabelColor)
        label.alignment = .right
        let gutter = NSStackView(views: [label])
        gutter.orientation = .vertical
        gutter.alignment = .trailing
        gutter.edgeInsets = NSEdgeInsets(top: Self.labelTop, left: 0, bottom: 0, right: 0)
        gutter.widthAnchor.constraint(equalToConstant: Self.labelWidth).isActive = true
        let content = NSStackView(views: lines)
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = Self.lineGap
        for line in lines where line is NSTextField {
            line.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        }
        let row = NSStackView(views: [gutter, content])
        row.alignment = .top
        row.spacing = Self.columnGap
        return row
    }

    private func aliasBox() -> NSView {
        aliasField.placeholderString = "Add alias"
        aliasField.setAccessibilityLabel("Add alias")
        aliasField.font = .systemFont(ofSize: Self.fontSize)
        aliasField.isBordered = false
        aliasField.drawsBackground = false
        aliasField.focusRingType = .none
        let inset = NSStackView(views: [aliasField])
        inset.edgeInsets = NSEdgeInsets(
            top: 0, left: Self.fieldInset, bottom: 0, right: Self.fieldInset)
        let box = Self.box(
            inset, height: Self.fieldHeight, radius: Self.fieldRadius, fill: Self.fieldFill,
            border: Self.fieldBorder)
        box.widthAnchor.constraint(equalToConstant: Self.fieldWidth).isActive = true
        return box
    }

    private func layoutButtons() -> NSView {
        let divider = FloatingCapsule.divider()
        let stack = NSStackView(views: [cancel, divider, save])
        stack.setCustomSpacing(Self.buttonsGap, after: cancel)
        stack.setCustomSpacing(Self.buttonsGap, after: divider)
        return FloatingCapsule.make(stack, leading: Self.buttonsInset, trailing: Self.buttonsInset)
    }
}
