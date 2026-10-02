import AppKit

@MainActor
final class ActionPanel: NSObject, NSTextFieldDelegate {
    private static let width: CGFloat = 316
    static let radius: CGFloat = 18
    static let inset: CGFloat = 6
    private static let rowGap: CGFloat = 1
    private static let headerTop: CGFloat = 6
    private static let headerSide: CGFloat = 10
    private static let headerBottom: CGFloat = 4
    private static let headerFontSize: CGFloat = 12
    private static let fieldHeight: CGFloat = 40
    private static let fieldSide: CGFloat = 16
    private static let fieldFontSize: CGFloat = 13
    private static let fieldFont = NSFont.systemFont(ofSize: fieldFontSize)
    private static let half: CGFloat = 0.5

    let glass = GlassView(shape: .rounded(radius))
    let header = NSTextField(labelWithString: "")
    let field = NSTextField()
    private let list = NSStackView()
    let empty = ActionRow.note("No matching actions")
    var onRun: ((Int) -> Void)?
    var onClose: (() -> Void)?
    private(set) var rows: [ActionRow] = []
    private var shown: [Int] = []
    private var selected = 0
    private var actions: [LauncherView.Action] = []

    var isVisible: Bool { unsafe glass.superview != nil }

    override init() {
        super.init()
        header.font = .systemFont(ofSize: Self.headerFontSize, weight: .semibold)
        header.textColor = .secondaryLabelColor
        header.lineBreakMode = .byTruncatingTail
        field.placeholderString = "Search for actions…"
        field.font = Self.fieldFont
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.delegate = self
        list.orientation = .vertical
        list.spacing = Self.rowGap
        list.setAccessibilityElement(true)
        list.setAccessibilityRole(.menu)
        glass.translatesAutoresizingMaskIntoConstraints = false
        glass.sheen.isHidden = true
        layout()
    }

    private static func edges(of view: NSView, to other: NSView) -> [NSLayoutConstraint] {
        [
            view.leadingAnchor.constraint(equalTo: other.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: other.trailingAnchor),
            view.topAnchor.constraint(equalTo: other.topAnchor),
            view.bottomAnchor.constraint(equalTo: other.bottomAnchor),
        ]
    }

    func show(
        _ actions: [LauncherView.Action], for title: String, above anchor: NSView, gap: CGFloat
    ) {
        guard let host = unsafe anchor.superview else { return }
        self.actions = actions
        header.stringValue = title
        list.setAccessibilityLabel("Actions for \(title)")
        field.stringValue = ""
        host.addSubview(glass)
        NSLayoutConstraint.activate([
            glass.widthAnchor.constraint(equalToConstant: Self.width),
            glass.trailingAnchor.constraint(equalTo: anchor.trailingAnchor),
            glass.bottomAnchor.constraint(equalTo: anchor.topAnchor, constant: -gap),
        ])
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
        case "k":
            close()

        case let key where LauncherView.returnKeys.contains(key):
            let secondary = LauncherView.Action.secondaryKeys
            guard let index = actions.firstIndex(where: { $0.keys == secondary }) else {
                return false
            }
            onRun?(index)

        default: return false
        }
        return true
    }

    private func filter() {
        let query = field.stringValue.trimmingCharacters(in: .whitespaces)
        shown = actions.indices.filter { index in
            query.isEmpty || actions[index].title.localizedStandardContains(query)
        }
        for row in list.arrangedSubviews {
            row.removeFromSuperview()
        }
        rows = shown.map { index in
            let row = ActionRow(title: actions[index].title, keys: actions[index].keys)
            row.onPress = { [weak self] in self?.onRun?(index) }
            return row
        }
        for row in rows.isEmpty ? [empty] : rows {
            list.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
        }
        selected = 0
        rows.first?.isSelected = true
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

    private func layout() {
        let content = NSView()
        let separator = NSBox()
        separator.boxType = .separator
        let border = GlassBorder(radius: Self.radius)
        for view in [header, list, separator, field, border] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        let headerInset = Self.inset + Self.headerSide
        NSLayoutConstraint.activate(
            [
                header.topAnchor.constraint(
                    equalTo: content.topAnchor, constant: Self.inset + Self.headerTop),
                header.leadingAnchor.constraint(
                    equalTo: content.leadingAnchor, constant: headerInset),
                header.trailingAnchor.constraint(
                    lessThanOrEqualTo: content.trailingAnchor, constant: -headerInset),
                list.topAnchor.constraint(
                    equalTo: header.bottomAnchor, constant: Self.headerBottom),
                list.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Self.inset),
                list.trailingAnchor.constraint(
                    equalTo: content.trailingAnchor, constant: -Self.inset),
                separator.topAnchor.constraint(equalTo: list.bottomAnchor, constant: Self.inset),
                separator.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                separator.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            ] + fieldLayout(below: separator, in: content)
                + Self.edges(of: border, to: content))
        glass.contentView = content
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(Self.edges(of: content, to: glass))
    }

    private func fieldLayout(below separator: NSView, in content: NSView) -> [NSLayoutConstraint] {
        let area = NSLayoutGuide()
        content.addLayoutGuide(area)
        let capCentre = Self.fieldFont.capHeight * Self.half
        return [
            area.topAnchor.constraint(equalTo: separator.bottomAnchor),
            area.heightAnchor.constraint(equalToConstant: Self.fieldHeight),
            area.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            field.firstBaselineAnchor.constraint(equalTo: area.centerYAnchor, constant: capCentre),
            field.leadingAnchor.constraint(
                equalTo: content.leadingAnchor, constant: Self.fieldSide),
            field.trailingAnchor.constraint(
                equalTo: content.trailingAnchor, constant: -Self.fieldSide),
        ]
    }
}
