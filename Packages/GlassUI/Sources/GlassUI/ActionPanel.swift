import AppKit

@MainActor
final class ActionPanel: NSObject, NSTextFieldDelegate {
    private static let width: CGFloat = 316
    private static let shortcuts = [["↵"], ["⌘", "↵"]]
    private static let radius: CGFloat = 18
    private static let inset: CGFloat = 6
    private static let rowGap: CGFloat = 1
    private static let headerTop: CGFloat = 6
    private static let headerSide: CGFloat = 10
    private static let headerBottom: CGFloat = 4
    private static let headerFontSize: CGFloat = 12
    private static let fieldHeight: CGFloat = 40
    private static let fieldSide: CGFloat = 16
    private static let fieldFontSize: CGFloat = 13

    let glass = GlassView(shape: .rounded(radius))
    let header = NSTextField(labelWithString: "")
    let field = NSTextField()
    private let list = NSStackView()
    var onRun: ((Int) -> Void)?
    var onClose: (() -> Void)?
    private(set) var rows: [ActionRow] = []
    private var shown: [Int] = []
    private var selected = 0
    private var titles: [String] = []
    private var height: NSLayoutConstraint?

    var isVisible: Bool { unsafe glass.superview != nil }

    override init() {
        super.init()
        header.font = .systemFont(ofSize: Self.headerFontSize, weight: .semibold)
        header.textColor = .secondaryLabelColor
        header.lineBreakMode = .byTruncatingTail
        field.placeholderString = "Search for actions…"
        field.font = .systemFont(ofSize: Self.fieldFontSize)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.delegate = self
        list.orientation = .vertical
        list.spacing = Self.rowGap
        list.setAccessibilityElement(true)
        list.setAccessibilityRole(.menu)
        glass.translatesAutoresizingMaskIntoConstraints = false
        layout()
    }

    func show(_ titles: [String], for title: String, above anchor: NSView, gap: CGFloat) {
        guard let host = unsafe anchor.superview else { return }
        self.titles = titles
        header.stringValue = title
        list.setAccessibilityLabel("Actions for \(title)")
        field.stringValue = ""
        host.addSubview(glass)
        let fit = glass.heightAnchor.constraint(equalToConstant: Self.fieldHeight)
        NSLayoutConstraint.activate([
            glass.widthAnchor.constraint(equalToConstant: Self.width),
            glass.trailingAnchor.constraint(equalTo: anchor.trailingAnchor),
            glass.bottomAnchor.constraint(equalTo: anchor.topAnchor, constant: -gap),
            fit,
        ])
        height = fit
        filter()
        unsafe host.window?.makeFirstResponder(field)
    }

    func close() {
        guard isVisible else { return }
        glass.removeFromSuperview()
        onClose?()
    }

    func contains(_ point: NSPoint) -> Bool {
        isVisible && glass.convert(glass.bounds, to: nil).contains(point)
    }

    func controlTextDidChange(_: Notification) {
        filter()
    }

    func control(_: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveUp): select(selected - 1)
        case #selector(NSResponder.moveDown): select(selected + 1)
        case #selector(NSResponder.insertNewline) where !textView.hasMarkedText(): runSelected()
        case #selector(NSResponder.cancelOperation): close()
        default: return false
        }
        return true
    }

    func performShortcut(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(LauncherView.modifierKeys) == .command,
            (field.currentEditor() as? NSTextView)?.hasMarkedText() != true
        else { return false }
        switch event.charactersIgnoringModifiers {
        case "k": close()
        case let key where LauncherView.returnKeys.contains(key) && titles.count > 1: onRun?(1)
        default: return false
        }
        return true
    }

    private func filter() {
        let query = field.stringValue.trimmingCharacters(in: .whitespaces)
        shown = titles.indices.filter { index in
            query.isEmpty || titles[index].localizedStandardContains(query)
        }
        for row in rows {
            row.removeFromSuperview()
        }
        rows = shown.map { index in
            let row = ActionRow(
                title: titles[index],
                keys: Self.shortcuts.indices.contains(index) ? Self.shortcuts[index] : [])
            row.onPress = { [weak self] in self?.onRun?(index) }
            return row
        }
        for row in rows {
            list.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
        }
        selected = 0
        rows.first?.isSelected = true
        resize()
    }

    private func runSelected() {
        if shown.indices.contains(selected) {
            onRun?(shown[selected])
        }
    }

    private func select(_ index: Int) {
        guard rows.indices.contains(index) else { return }
        rows[selected].isSelected = false
        selected = index
        rows[index].isSelected = true
    }

    private func resize() {
        height?.constant = glass.contentView?.fittingSize.height ?? Self.fieldHeight
    }

    private func layout() {
        let content = NSView()
        let separator = NSBox()
        separator.boxType = .separator
        let fieldArea = NSLayoutGuide()
        content.addLayoutGuide(fieldArea)
        let border = GlassBorder(radius: Self.radius)
        for view in [header, list, separator, field, border] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        let headerInset = Self.inset + Self.headerSide
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(
                equalTo: content.topAnchor, constant: Self.inset + Self.headerTop),
            header.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: headerInset),
            header.trailingAnchor.constraint(
                lessThanOrEqualTo: content.trailingAnchor, constant: -headerInset),
            list.topAnchor.constraint(equalTo: header.bottomAnchor, constant: Self.headerBottom),
            list.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Self.inset),
            list.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Self.inset),
            separator.topAnchor.constraint(equalTo: list.bottomAnchor, constant: Self.inset),
            separator.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            fieldArea.topAnchor.constraint(equalTo: separator.bottomAnchor),
            fieldArea.heightAnchor.constraint(equalToConstant: Self.fieldHeight),
            fieldArea.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            field.centerYAnchor.constraint(equalTo: fieldArea.centerYAnchor),
            field.leadingAnchor.constraint(
                equalTo: content.leadingAnchor, constant: Self.fieldSide),
            field.trailingAnchor.constraint(
                equalTo: content.trailingAnchor, constant: -Self.fieldSide),
            border.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            border.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            border.topAnchor.constraint(equalTo: content.topAnchor),
            border.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        glass.contentView = content
    }
}
