import AppKit

@MainActor
final class StatusBarCustomiser: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private enum Row {
        case heading(String, top: CGFloat)
        case pill(StatusBar.Pill, shown: Bool)

        var key: String {
            switch self {
            case .heading(let title, _): title
            case let .pill(pill, shown): "\(pill.id) \(shown)"
            }
        }
    }

    static let width: CGFloat = 380
    static let height: CGFloat = 340
    static let gap: CGFloat = 12
    static let radius: CGFloat = 20
    static let headingFont = NSFont.systemFont(ofSize: headingSize, weight: .semibold)
    static let headingBottom: CGFloat = 4
    private static let headingSize: CGFloat = 11.5
    private static let showingTop: CGFloat = 10
    private static let moreTop: CGFloat = 12
    private static let rowGap: CGFloat = 1
    private static let pillType = NSPasteboard.PasteboardType("com.taroj1205.mado.status-pill")
    private static let headingLine = NSLayoutManager().defaultLineHeight(for: headingFont)

    let glass = GlassView(shape: .rounded(radius))
    let table = NSTableView()
    let count = NSTextField(labelWithString: "")
    private(set) lazy var done = AccentButton("Done", target: self, action: #selector(finish))
    private(set) lazy var reset = NSButton(
        title: "Reset to default", target: self, action: #selector(resetLayout))
    var onToggle: ((String, Bool) -> Void)?
    var onMove: ((String, String?) -> Void)?
    var onReset: (() -> Void)?
    var onDone: (() -> Void)?
    private var rows: [Row] = []
    private var shownCount = 0

    var isVisible: Bool { unsafe glass.superview != nil }

    override init() {
        super.init()
        glass.sheen.isHidden = true
        glass.translatesAutoresizingMaskIntoConstraints = false
        glass.setAccessibilityElement(true)
        glass.setAccessibilityRole(.popover)
        glass.setAccessibilityLabel("Customise status bar")
        setUpTable()
        let content = makeContent()
        glass.contentView = content
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
            content.topAnchor.constraint(equalTo: glass.topAnchor),
            content.bottomAnchor.constraint(equalTo: glass.bottomAnchor),
        ])
        let border = GlassBorder(radius: Self.radius)
        border.frame = glass.container.bounds
        border.autoresizingMask = [.width, .height]
        glass.container.addSubview(border)
    }

    func show(_ shown: [StatusBar.Pill], more: [StatusBar.Pill]) {
        let next =
            [.heading("Showing", top: Self.showingTop)] + shown.map { Row.pill($0, shown: true) }
            + [.heading("More", top: Self.moreTop)] + more.map { Row.pill($0, shown: false) }
        let reorders = next.map(\.key) != rows.map(\.key)
        rows = next
        shownCount = shown.count
        count.stringValue = "\(shown.count) of \(shown.count + more.count) shown"
        if reorders {
            table.reloadData()
            return
        }
        for (index, row) in rows.enumerated() {
            guard case .pill(let pill, _) = row,
                let view = table.view(atColumn: 0, row: index, makeIfNecessary: false)
                    as? CustomiserRow
            else { continue }
            view.show(pill)
        }
    }

    func numberOfRows(in _: NSTableView) -> Int {
        rows.count
    }

    func tableView(_: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard case .heading(_, let top) = rows[row] else { return CustomiserRow.height }
        return top + Self.headingLine.rounded(.up) + Self.headingBottom
    }

    func tableView(_: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        switch rows[row] {
        case .heading(let title, _):
            return Self.heading(title)

        case let .pill(pill, shown):
            let view = CustomiserRow(shown: shown)
            view.show(pill)
            view.onToggle = { [weak self] isOn in self?.onToggle?(pill.id, isOn) }
            return view
        }
    }

    func tableView(_: NSTableView, pasteboardWriterForRow row: Int) -> (
        any NSPasteboardWriting
    )? {
        guard case .pill(let pill, true) = rows[row] else { return nil }
        let item = NSPasteboardItem()
        item.setString(pill.id, forType: Self.pillType)
        return item
    }

    func tableView(
        _ tableView: NSTableView, validateDrop info: any NSDraggingInfo, proposedRow row: Int,
        proposedDropOperation operation: NSTableView.DropOperation
    ) -> NSDragOperation {
        let local = (info.draggingSource as? NSTableView) === tableView
        return local && operation == .above && (1...shownCount + 1).contains(row) ? .move : []
    }

    func tableView(
        _: NSTableView, acceptDrop info: any NSDraggingInfo, row: Int,
        dropOperation _: NSTableView.DropOperation
    ) -> Bool {
        guard let id = info.draggingPasteboard.string(forType: Self.pillType) else {
            return false
        }
        let target: String? = if case .pill(let pill, true) = rows[row] { pill.id } else { nil }
        onMove?(id, target)
        return true
    }

    private func setUpTable() {
        let column = NSTableColumn(identifier: .init("pill"))
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.headerView = nil
        table.style = .plain
        table.backgroundColor = .clear
        table.intercellSpacing = NSSize(width: 0, height: Self.rowGap)
        table.selectionHighlightStyle = .none
        table.refusesFirstResponder = true
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.setAccessibilityLabel("Status bar pills")
        table.registerForDraggedTypes([Self.pillType])
        table.setDraggingSourceOperationMask(.move, forLocal: true)
        table.draggingDestinationFeedbackStyle = .gap
        table.dataSource = self
        table.delegate = self
    }

    @objc
    private func finish() {
        onDone?()
    }

    @objc
    private func resetLayout() {
        onReset?()
    }
}
