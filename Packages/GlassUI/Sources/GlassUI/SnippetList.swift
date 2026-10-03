import AppKit

final class SnippetList: NSScrollView, NSTableViewDataSource, NSTableViewDelegate {
    private final class Cell: NSTableCellView {
        private static let inset: CGFloat = 10
        private static let gap: CGFloat = 8
        private static let nameSize: CGFloat = 13
        private static let keywordSize: CGFloat = 11.5

        let name = NSTextField(labelWithString: "")
        let keyword = NSTextField(labelWithString: "")

        override init(frame: NSRect) {
            super.init(frame: frame)
            identifier = SnippetList.cellID
            name.font = .systemFont(ofSize: Self.nameSize, weight: .medium)
            name.lineBreakMode = .byTruncatingTail
            name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            keyword.font = .monospacedSystemFont(ofSize: Self.keywordSize, weight: .regular)
            keyword.textColor = .secondaryLabelColor
            keyword.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
            setAccessibilityChildren([])
            for view in [name, keyword] {
                view.translatesAutoresizingMaskIntoConstraints = false
                addSubview(view)
                view.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
            }
            NSLayoutConstraint.activate([
                name.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.inset),
                keyword.leadingAnchor.constraint(
                    greaterThanOrEqualTo: name.trailingAnchor, constant: Self.gap),
                keyword.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.inset),
            ])
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        func show(_ entry: SnippetEditor.Entry) {
            name.stringValue = entry.values.name
            keyword.stringValue = entry.values.keyword
            setAccessibilityLabel("\(entry.values.name), keyword \(entry.values.keyword)")
        }
    }

    static let cellID = NSUserInterfaceItemIdentifier("snippet")
    static let rowHeight: CGFloat = 40
    private static let radius: CGFloat = 10
    private static let topInset: CGFloat = 4

    let table = NSTableView()
    var onSelect: ((String?) -> Void)?
    private var choosing = false

    var entries: [SnippetEditor.Entry] = [] {
        didSet {
            choosing = true
            table.reloadData()
            choosing = false
        }
    }

    var selectedID: String? {
        entries.indices.contains(table.selectedRow) ? entries[table.selectedRow].id : nil
    }

    init() {
        super.init(frame: .zero)
        let column = NSTableColumn()
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.headerView = nil
        table.style = .plain
        table.backgroundColor = .clear
        table.intercellSpacing = NSSize(width: 0, height: ResultList.rowGap)
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.focusRingType = .none
        table.refusesFirstResponder = true
        table.rowHeight = Self.rowHeight
        table.dataSource = self
        table.delegate = self
        table.setAccessibilityLabel("Snippets")
        documentView = table
        drawsBackground = false
        hasVerticalScroller = true
        automaticallyAdjustsContentInsets = false
        contentInsets = NSEdgeInsets(top: Self.topInset, left: 0, bottom: 0, right: 0)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func select(_ id: String?) {
        choosing = true
        defer { choosing = false }
        guard let row = entries.firstIndex(where: { $0.id == id }) else {
            table.deselectAll(nil)
            return
        }
        table.selectRowIndexes([row], byExtendingSelection: false)
        table.scrollRowToVisible(row)
    }

    func move(by step: Int) {
        guard !entries.isEmpty else { return }
        let start = table.selectedRow < 0 ? (step > 0 ? -1 : entries.count) : table.selectedRow
        let row = min(max(start + step, 0), entries.count - 1)
        guard row != table.selectedRow else { return }
        table.selectRowIndexes([row], byExtendingSelection: false)
        table.scrollRowToVisible(row)
    }

    func numberOfRows(in _: NSTableView) -> Int {
        entries.count
    }

    func tableViewSelectionDidChange(_: Notification) {
        guard !choosing else { return }
        onSelect?(selectedID)
    }

    func tableView(_ tableView: NSTableView, rowViewForRow _: Int) -> NSTableRowView? {
        let view =
            tableView.makeView(withIdentifier: ResultRowView.id, owner: nil) as? ResultRowView
            ?? ResultRowView()
        view.radius = Self.radius
        return view
    }

    func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: Self.cellID, owner: nil) as? Cell ?? Cell()
        cell.show(entries[row])
        return cell
    }
}
