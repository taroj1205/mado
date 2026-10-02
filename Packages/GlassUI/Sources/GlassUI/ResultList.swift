public import AppKit

public final class ResultList: NSScrollView, NSTableViewDataSource, NSTableViewDelegate {
    public struct Item: Sendable, Equatable {
        public let id: String
        public let title: String
        public let subtitle: String
        public let kind: String
        public let symbol: String
        public let action: String
        public let icon: NSImage?
        public let file: URL?
        public let answer: Answer?
        public let keys: [String]

        public init(
            id: String, title: String, subtitle: String, kind: String, symbol: String,
            action: String, icon: NSImage? = nil, file: URL? = nil, answer: Answer? = nil,
            keys: [String] = []
        ) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.kind = kind
            self.symbol = symbol
            self.action = action
            self.icon = icon
            self.file = file
            self.answer = answer
            self.keys = keys
        }
    }

    public struct Answer: Sendable, Equatable {
        public let value: String
        public let detail: String

        public init(value: String, detail: String) {
            self.value = value
            self.detail = detail
        }
    }

    public struct Notice: Sendable, Equatable {
        public let title: String
        public let detail: String

        public init(title: String, detail: String) {
            self.title = title
            self.detail = detail
        }
    }

    public struct Section: Sendable, Equatable {
        public let title: String
        public let items: [Item]
        public let notice: Notice?
        public let colour: ColourCard?

        public init(
            title: String, items: [Item], notice: Notice? = nil, colour: ColourCard? = nil
        ) {
            self.title = title
            self.items = items
            self.notice = notice
            self.colour = colour
        }
    }

    enum Row: Equatable {
        case notice(Notice)
        case colour(ColourCard)
        case header(String)
        case item(Item)

        var isItem: Bool {
            itemID != nil
        }

        var itemID: String? {
            if case .item(let item) = self { item.id } else { nil }
        }
    }

    static let rowHeight: CGFloat = 42
    static let answerHeight: CGFloat = 116
    static let headerHeight: CGFloat = 32
    static let noticeHeight: CGFloat = 80
    static let colourHeight: CGFloat = 142
    static let rowGap: CGFloat = 1
    static let topInset: CGFloat = 4
    private static let headerInset: CGFloat = 12
    private static let headerBottom: CGFloat = 6
    private static let headerFontSize: CGFloat = 12
    private static let headerID = NSUserInterfaceItemIdentifier("header")

    public var sections: [Section] = [] {
        didSet {
            reloading = true
            rows = Self.rows(for: sections)
            table.reloadData()
            let keptRow = kept.flatMap { id in rows.firstIndex { $0.itemID == id } }
            if let row = keptRow ?? rows.firstIndex(where: \.isItem) {
                table.selectRowIndexes([row], byExtendingSelection: false)
            }
            table.scrollRowToVisible(keptRow ?? 0)
            reloading = false
            onSelect?(selectedItem)
        }
    }

    public var onSelect: ((Item?) -> Void)?
    public var onMove: (() -> Void)?

    public var selectedItem: Item? {
        guard rows.indices.contains(table.selectedRow),
            case .item(let item) = rows[table.selectedRow]
        else { return nil }
        return item
    }

    let table = NSTableView()
    private(set) var rows: [Row] = []
    private var reloading = false
    private var kept: String?

    public init() {
        super.init(frame: .zero)
        let column = NSTableColumn()
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.headerView = nil
        table.style = .plain
        table.allowsEmptySelection = false
        table.backgroundColor = .clear
        table.intercellSpacing = NSSize(width: 0, height: Self.rowGap)
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.focusRingType = .none
        table.refusesFirstResponder = true
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.action = #selector(rowClicked)
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
            .flatMap { section in
                (section.notice.map { [Row.notice($0)] } ?? [])
                    + (section.colour.map { [Row.colour($0)] } ?? [])
                    + [.header(section.title)] + section.items.map(Row.item)
            }
    }

    public func update(_ sections: [Section], keepingSelectionOf id: String?) {
        kept = id
        self.sections = sections
        kept = nil
    }

    @objc
    func rowClicked() {
        onMove?()
    }

    public func selectPrevious() {
        moveSelection(by: -1)
    }

    public func selectNext() {
        moveSelection(by: 1)
    }

    private func moveSelection(by step: Int) {
        var row = table.selectedRow + step
        while rows.indices.contains(row), !rows[row].isItem {
            row += step
        }
        guard rows.indices.contains(row) else { return }
        table.selectRowIndexes([row], byExtendingSelection: false)
        table.scrollRowToVisible(rows[..<row].lastIndex(where: \.isItem).map { $0 + 1 } ?? 0)
        table.scrollRowToVisible(row)
    }

    public func numberOfRows(in _: NSTableView) -> Int {
        rows.count
    }

    public func tableView(_: NSTableView, heightOfRow row: Int) -> CGFloat {
        switch rows[row] {
        case .notice: Self.noticeHeight
        case .colour: Self.colourHeight
        case .header: Self.headerHeight
        case .item(let item): item.answer == nil ? Self.rowHeight : Self.answerHeight
        }
    }

    public func tableView(_: NSTableView, shouldSelectRow row: Int) -> Bool {
        rows[row].isItem
    }

    public func tableViewSelectionDidChange(_: Notification) {
        guard !reloading else { return }
        onSelect?(selectedItem)
    }

    public func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let view =
            tableView.makeView(withIdentifier: ResultRowView.id, owner: nil) as? ResultRowView
            ?? ResultRowView()
        let answer = if case .item(let item) = rows[row] { item.answer != nil } else { false }
        view.radius = answer ? AnswerCell.radius : ResultRowView.radius
        return view
    }

    public func tableView(
        _ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int
    ) -> NSView? {
        switch rows[row] {
        case .notice(let notice):
            let cell =
                tableView.makeView(withIdentifier: NoticeCell.id, owner: nil)
                as? NoticeCell ?? NoticeCell()
            cell.show(notice)
            return cell

        case .colour(let card):
            let cell =
                tableView.makeView(withIdentifier: ColourCell.id, owner: nil)
                as? ColourCell ?? ColourCell()
            cell.show(card)
            return cell

        case .header(let title):
            let cell =
                tableView.makeView(withIdentifier: Self.headerID, owner: nil)
                as? NSTableCellView ?? makeHeader()
            unsafe cell.textField?.stringValue = title
            return cell

        case .item(let item) where item.answer != nil:
            let cell =
                tableView.makeView(withIdentifier: AnswerCell.id, owner: nil)
                as? AnswerCell ?? AnswerCell()
            cell.show(item)
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
        label.lineBreakMode = .byTruncatingTail
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
