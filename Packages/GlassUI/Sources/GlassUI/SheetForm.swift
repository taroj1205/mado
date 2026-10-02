import AppKit

@MainActor
enum SheetForm {
    private static let formLeading: CGFloat = 10
    private static let formTrailing: CGFloat = 40
    private static let rowGap: CGFloat = 14
    private static let labelWidth: CGFloat = 130
    private static let labelTop: CGFloat = 6
    private static let columnGap: CGFloat = 14
    private static let lineGap: CGFloat = 6
    private static let controlGap: CGFloat = 10
    static let fontSize: CGFloat = 13
    static let font = NSFont.systemFont(ofSize: fontSize)
    private static let headerInset: CGFloat = 20
    static let hintSize: CGFloat = 12
    private static let fieldHeight: CGFloat = 28
    private static let fieldRadius: CGFloat = 8
    private static let fieldInset: CGFloat = 10
    private static let fieldAlpha = (dark: 0.20, light: 0.05)
    private static let fieldBorderAlpha = (dark: 0.10, light: 0.12)
    private static let half: CGFloat = 0.5
    private static let capsuleInset: CGFloat = 10
    private static let buttonsInset: CGFloat = 5
    private static let buttonsGap: CGFloat = 6
    private static let fieldFill = adaptive(
        dark: .black.withAlphaComponent(fieldAlpha.dark),
        light: .black.withAlphaComponent(fieldAlpha.light))
    private static let fieldBorder = adaptive(
        dark: .white.withAlphaComponent(fieldBorderAlpha.dark),
        light: .black.withAlphaComponent(fieldBorderAlpha.light))

    static func adaptive(dark: NSColor, light: NSColor) -> NSColor {
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

    static func label(_ text: String, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        return label
    }

    static func line(_ views: [NSView]) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.spacing = controlGap
        stack.setHuggingPriority(.defaultHigh, for: .horizontal)
        return stack
    }

    static func box(
        _ content: NSView, height: CGFloat, radius: CGFloat, fill: NSColor,
        border: NSColor?
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

    static func field(
        _ field: NSTextField, label: String, width: CGFloat?, font: NSFont
    ) -> NSBox {
        field.setAccessibilityLabel(label)
        field.font = font
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let inset = NSStackView(views: [field])
        inset.edgeInsets = NSEdgeInsets(
            top: 0, left: fieldInset, bottom: 0, right: fieldInset)
        let box = box(
            inset, height: fieldHeight, radius: fieldRadius, fill: fieldFill, border: fieldBorder)
        if let width {
            box.widthAnchor.constraint(equalToConstant: width).isActive = true
        }
        return box
    }

    static func row(_ name: String, _ lines: [NSView]) -> NSView {
        let label = label(name, color: .secondaryLabelColor)
        label.alignment = .right
        let gutter = NSStackView(views: [label])
        gutter.orientation = .vertical
        gutter.alignment = .trailing
        gutter.edgeInsets = NSEdgeInsets(top: labelTop, left: 0, bottom: 0, right: 0)
        gutter.widthAnchor.constraint(equalToConstant: labelWidth).isActive = true
        let content = NSStackView(views: lines)
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = lineGap
        for line in lines where line is NSTextField || line is NSBox {
            line.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        }
        let row = NSStackView(views: [gutter, content])
        row.alignment = .top
        row.spacing = columnGap
        content.widthAnchor.constraint(
            equalTo: row.widthAnchor, constant: -labelWidth - columnGap
        ).isActive = true
        return row
    }

    static func form(_ rows: [NSView]) -> NSStackView {
        let form = NSStackView(views: rows)
        form.orientation = .vertical
        form.alignment = .leading
        form.spacing = rowGap
        for row in rows {
            row.widthAnchor.constraint(equalTo: form.widthAnchor).isActive = true
        }
        return form
    }

    static func buttons(_ cancel: NSView, _ save: NSView) -> NSView {
        let divider = FloatingCapsule.divider()
        let stack = NSStackView(views: [cancel, divider, save])
        stack.setCustomSpacing(buttonsGap, after: cancel)
        stack.setCustomSpacing(buttonsGap, after: divider)
        return FloatingCapsule.make(stack, leading: buttonsInset, trailing: buttonsInset)
    }

    static func place(
        _ header: NSView, height: CGFloat, form: NSView, top: CGFloat, in sheet: NSView
    ) {
        let separator = NSBox()
        separator.boxType = .separator
        for view in [header, separator, form] {
            view.translatesAutoresizingMaskIntoConstraints = false
            sheet.addSubview(view)
        }
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: headerInset),
            header.trailingAnchor.constraint(
                lessThanOrEqualTo: sheet.trailingAnchor, constant: -headerInset),
            header.centerYAnchor.constraint(equalTo: sheet.topAnchor, constant: height * half),
            separator.topAnchor.constraint(equalTo: sheet.topAnchor, constant: height),
            separator.leadingAnchor.constraint(equalTo: sheet.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: sheet.trailingAnchor),
            form.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: top),
            form.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: formLeading),
            form.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -formTrailing),
        ])
    }

    static func placeCapsules(_ context: NSView, _ buttons: NSView, in sheet: NSView) {
        for view in [context, buttons] {
            view.translatesAutoresizingMaskIntoConstraints = false
            sheet.addSubview(view)
        }
        NSLayoutConstraint.activate([
            context.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: capsuleInset),
            context.centerYAnchor.constraint(equalTo: buttons.centerYAnchor),
            buttons.trailingAnchor.constraint(
                equalTo: sheet.trailingAnchor, constant: -capsuleInset),
            buttons.bottomAnchor.constraint(equalTo: sheet.bottomAnchor, constant: -capsuleInset),
        ])
    }
}
