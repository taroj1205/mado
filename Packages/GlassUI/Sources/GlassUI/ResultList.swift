public import AppCore
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
        public let thumbnail: URL?
        public let answer: Answer?
        public let tint: NSColor?
        public let shortcut: [String]
        public var hotkey: Shortcut?
        public var isDimmed = false
        public var glyph: String?
        public var event: Event?
        public var prefersSelection = false

        public init(
            id: String, title: String, subtitle: String, kind: String, symbol: String,
            action: String, icon: NSImage? = nil, file: URL? = nil, thumbnail: URL? = nil,
            answer: Answer? = nil, tint: NSColor? = nil, shortcut: [String] = []
        ) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.kind = kind
            self.symbol = symbol
            self.action = action
            self.icon = icon
            self.file = file
            self.thumbnail = thumbnail
            self.answer = answer
            self.tint = tint
            self.shortcut = shortcut
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

    enum Row: Equatable {
        case notice(Notice)
        case card(Card)
        case colour(ColourCard)
        case header(String)
        case item(Item)

        var isItem: Bool {
            itemID != nil
        }

        var itemID: String? {
            if case .item(let item) = self { item.id } else { nil }
        }

        var prefersSelection: Bool {
            if case .item(let item) = self { item.prefersSelection } else { false }
        }
    }

    static let rowHeight: CGFloat = 42
    static let compactRowHeight: CGFloat = 36
    static let eventHeight: CGFloat = 44
    static let compactRadius: CGFloat = 8
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
            let shown = rows.count
            rows = Self.rows(for: sections)
            reloadRows(keeping: shown)
            let keptRow = kept.flatMap { id in rows.firstIndex { $0.itemID == id } }
            let preferred = rows.firstIndex(where: \.prefersSelection)
            if let row = keptRow ?? preferred ?? rows.firstIndex(where: \.isItem) {
                table.selectRowIndexes([row], byExtendingSelection: false)
            }
            reveal(keptRow ?? preferred ?? 0, context: keptRow == nil ? [0] : [], animated: false)
            reloading = false
            onSelect?(selectedItem)
        }
    }

    public var compact = false {
        didSet { table.reloadData() }
    }

    public var onSelect: ((Item?) -> Void)?
    public var onMove: (() -> Void)?
    public var onPick: ((String) -> Void)?

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
    var heading: NSPoint?
    var reducesMotion = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

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
        sections.filter { !$0.items.isEmpty || $0.notice != nil }
            .flatMap { section in
                let above: [Row?] = [
                    section.notice.map(Row.notice), section.card.map(Row.card),
                    section.colour.map(Row.colour),
                ]
                let items = section.items.map(Row.item)
                return above.compactMap(\.self) + (items.isEmpty ? [] : [.header(section.title)])
                    + items
            }
    }

    public func update(_ sections: [Section], keepingSelectionOf id: String?) {
        kept = id
        self.sections = sections
        kept = nil
    }

    override public func scrollWheel(with event: NSEvent) {
        stopGliding()
        super.scrollWheel(with: event)
    }

    @objc
    func rowClicked() {
        onMove?()
    }

    public func numberOfRows(in _: NSTableView) -> Int {
        rows.count
    }

    public func tableView(_: NSTableView, heightOfRow row: Int) -> CGFloat {
        switch rows[row] {
        case .notice: Self.noticeHeight
        case .card(let card): DefinitionCell.height(for: card, width: contentSize.width)
        case .colour: Self.colourHeight
        case .header: Self.headerHeight
        case .item(let item) where item.answer != nil: Self.answerHeight
        case .item(let item) where item.event != nil: Self.eventHeight
        case .item: compact ? Self.compactRowHeight : Self.rowHeight
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
        view.radius = radius(ofRow: row)
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

        case .card(let card):
            let cell =
                tableView.makeView(withIdentifier: DefinitionCell.id, owner: nil)
                as? DefinitionCell ?? DefinitionCell()
            cell.show(card, width: contentSize.width)
            cell.onPick = { [weak self] in self?.onPick?($0) }
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

        case .item(let item):
            return cell(for: item, in: tableView)
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
