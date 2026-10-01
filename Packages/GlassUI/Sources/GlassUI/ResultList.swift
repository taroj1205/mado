public import AppKit

public final class ResultList: NSScrollView, NSTableViewDataSource, NSTableViewDelegate {
    public struct Item: Sendable, Equatable {
        public let title: String
        public let subtitle: String
        public let kind: String
        public let symbol: String

        public init(title: String, subtitle: String, kind: String, symbol: String) {
            self.title = title
            self.subtitle = subtitle
            self.kind = kind
            self.symbol = symbol
        }
    }

    public struct Section: Sendable, Equatable {
        public let title: String
        public let items: [Item]

        public init(title: String, items: [Item]) {
            self.title = title
            self.items = items
        }
    }

    enum Row: Equatable {
        case header(String)
        case item(Item)

        var isItem: Bool {
            if case .item = self { true } else { false }
        }
    }

    static let rowHeight: CGFloat = 42
    static let headerHeight: CGFloat = 32
    static let rowGap: CGFloat = 1
    static let topInset: CGFloat = 4
    private static let headerInset: CGFloat = 12
    private static let headerBottom: CGFloat = 6
    private static let headerFontSize: CGFloat = 12
    private static let headerID = NSUserInterfaceItemIdentifier("header")

    public var sections: [Section] = [] {
        didSet {
            rows = Self.rows(for: sections)
            table.reloadData()
            if let first = rows.firstIndex(where: \.isItem) {
                table.selectRowIndexes([first], byExtendingSelection: false)
            }
            table.scrollRowToVisible(0)
        }
    }

    let table = NSTableView()
    private(set) var rows: [Row] = []

    public init() {
        super.init(frame: .zero)
        let column = NSTableColumn()
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.headerView = nil
        table.style = .plain
        table.backgroundColor = .clear
        table.intercellSpacing = NSSize(width: 0, height: Self.rowGap)
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.focusRingType = .none
        table.refusesFirstResponder = true
        table.dataSource = self
        table.delegate = self
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

    static func rows(for sections: [Section]) -> [Row] {
        sections.filter { !$0.items.isEmpty }
            .flatMap { [.header($0.title)] + $0.items.map(Row.item) }
    }

    public func numberOfRows(in _: NSTableView) -> Int {
        rows.count
    }

    public func tableView(_: NSTableView, heightOfRow row: Int) -> CGFloat {
        if case .header = rows[row] { Self.headerHeight } else { Self.rowHeight }
    }

    public func tableView(_: NSTableView, shouldSelectRow row: Int) -> Bool {
        rows[row].isItem
    }

    public func tableView(_ tableView: NSTableView, rowViewForRow _: Int) -> NSTableRowView? {
        tableView.makeView(withIdentifier: ResultRowView.id, owner: nil) as? ResultRowView
            ?? ResultRowView()
    }

    public func tableView(
        _ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int
    ) -> NSView? {
        switch rows[row] {
        case .header(let title):
            let cell =
                tableView.makeView(withIdentifier: Self.headerID, owner: nil)
                as? NSTableCellView ?? makeHeader()
            unsafe cell.textField?.stringValue = title
            return cell

        case .item(let item):
            let cell =
                tableView.makeView(withIdentifier: ResultCell.id, owner: nil)
                as? ResultCell ?? ResultCell()
            cell.show(item)
            return cell
        }
    }

    private func makeHeader() -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = Self.headerID
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: Self.headerFontSize, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)
        unsafe cell.textField = label
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: Self.headerInset),
            label.trailingAnchor.constraint(
                lessThanOrEqualTo: cell.trailingAnchor, constant: -Self.headerInset),
            label.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -Self.headerBottom),
        ])
        return cell
    }
}
