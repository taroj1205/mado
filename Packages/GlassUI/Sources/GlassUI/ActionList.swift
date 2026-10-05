import AppKit

final class ActionList: NSScrollView {
    private final class Stack: NSStackView {
        override var isFlipped: Bool { true }
    }

    private static let rowGap: CGFloat = 1
    private static let separatorGap: CGFloat = 5
    private static let separatorInsets: CGFloat = 20

    let empty = ActionRow.note("No matching actions")
    private(set) var rows: [ActionRow] = []
    private let stack = Stack()
    private var selected = 0

    init() {
        super.init(frame: .zero)
        stack.orientation = .vertical
        stack.spacing = Self.rowGap
        stack.setAccessibilityElement(true)
        stack.setAccessibilityRole(.menu)
        stack.translatesAutoresizingMaskIntoConstraints = false
        documentView = stack
        drawsBackground = false
        hasVerticalScroller = true
        autohidesScrollers = true
        let fits = heightAnchor.constraint(equalTo: stack.heightAnchor)
        fits.priority = .dragThatCannotResizeWindow
        NSLayoutConstraint.activate([
            fits,
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func show(_ rows: [ActionRow], groups: [Int], label: String) {
        stack.setAccessibilityLabel(label)
        for view in stack.arrangedSubviews {
            view.removeFromSuperview()
        }
        self.rows = rows
        for (index, row) in rows.enumerated() {
            row.onHover = { [weak self] in self?.select(index) }
            if index > 0, groups[index] != groups[index - 1] {
                addSeparator(after: rows[index - 1])
            }
            add(row)
        }
        if rows.isEmpty {
            add(empty)
        }
        selected = 0
        rows.first?.isSelected = true
        stack.scroll(.zero)
    }

    func moveSelection(by offset: Int) {
        let index = selected + offset
        guard select(index) else { return }
        rows[index].scrollToVisible(rows[index].bounds)
    }

    @discardableResult
    private func select(_ index: Int) -> Bool {
        guard rows.indices.contains(index) else { return false }
        if rows.indices.contains(selected) {
            rows[selected].isSelected = false
        }
        selected = index
        rows[index].isSelected = true
        return true
    }

    func press() {
        if rows.indices.contains(selected) {
            rows[selected].onPress?()
        }
    }

    private func add(_ row: ActionRow) {
        stack.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func addSeparator(after row: ActionRow) {
        let separator = NSBox()
        separator.boxType = .separator
        stack.setCustomSpacing(Self.separatorGap, after: row)
        stack.addArrangedSubview(separator)
        stack.setCustomSpacing(Self.separatorGap, after: separator)
        separator.widthAnchor.constraint(
            equalTo: stack.widthAnchor, constant: -Self.separatorInsets
        ).isActive = true
    }
}
