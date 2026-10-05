import AppKit
import SearchKit

final class SettingsSidebar: NSViewController {
    struct Target: Equatable {
        let place: SettingsSearch.Place
        let entry: String?
        let choice: Bool
    }

    enum Row {
        case page(Int)
        case group(SettingsSearch.Group)
        case recent
        case suggestion(SettingsSearch.Suggestion)
    }

    static let rowHeight: CGFloat = 28
    private static let rowGap: CGFloat = 2
    private static let fieldTop: CGFloat = 40
    private static let inset: CGFloat = 10
    private static let listGap: CGFloat = 8
    private static let emptyTop: CGFloat = 56
    static let recentSymbol = "clock"
    private static let pages = SettingsPage.all.indices.map(Row.page)

    weak var delegate: (any SettingsSidebarDelegate)?
    let finder: SettingsFinder
    let table = NSTableView()
    private let field = SettingsSearchField()
    private let empty = SettingsSidebarEmpty()
    var rows = SettingsSidebar.pages
    var groups: [SettingsSearch.Group] = []
    var page = 0
    var fieldFocused = false
    var reindexing = false

    var query: String {
        field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var searching: Bool {
        if case .page = rows.first { return false }
        return true
    }

    var matches: [String: [Int]] {
        Dictionary(
            groups.flatMap { $0.suggestions.map { ($0.entry, $0.title.matches) } }
        ) { first, _ in first }
    }

    init(finder: SettingsFinder) {
        self.finder = finder
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func loadView() {
        table.style = .sourceList
        table.headerView = nil
        table.allowsEmptySelection = false
        table.rowSizeStyle = .custom
        table.rowHeight = Self.rowHeight
        table.intercellSpacing = NSSize(width: 0, height: Self.rowGap)
        table.addTableColumn(NSTableColumn())
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.action = #selector(clicked)
        field.placeholderString = "Search"
        field.setAccessibilityLabel("Search settings")
        field.delegate = self
        field.onFocus = { [weak self] in
            self?.fieldFocused = true
            self?.finder.invalidate()
            self?.update()
        }
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.drawsBackground = false
        view = layOut(scroll)
        select(page: 0)
    }

    func select(page index: Int) {
        page = index
        guard !searching else { return }
        table.selectRowIndexes([index], byExtendingSelection: false)
    }

    func focusField() {
        unsafe view.window?.makeFirstResponder(field)
    }

    func endSearch() {
        field.stringValue = ""
        fieldFocused = false
        if unsafe view.window?.firstResponder === field.currentEditor() {
            unsafe view.window?.makeFirstResponder(nil)
        }
        update()
    }

    private func layOut(_ scroll: NSScrollView) -> NSView {
        let fill = NSBox()
        fill.boxType = .custom
        fill.titlePosition = .noTitle
        fill.borderWidth = 0
        fill.contentViewMargins = .zero
        fill.fillColor = SettingsWindowController.tint
        let content = NSView()
        fill.contentView = content
        for part in [field, scroll, empty] as [NSView] {
            part.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(part)
        }
        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: content.topAnchor, constant: Self.fieldTop),
            field.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Self.inset),
            field.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Self.inset),
            scroll.topAnchor.constraint(equalTo: field.bottomAnchor, constant: Self.listGap),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            empty.topAnchor.constraint(equalTo: field.bottomAnchor, constant: Self.emptyTop),
            empty.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Self.inset),
            empty.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Self.inset),
        ])
        return fill
    }

    func update() {
        refill()
        if !searching {
            delegate?.sidebarShowedPages()
            table.selectRowIndexes([page], byExtendingSelection: false)
            table.allowsEmptySelection = false
        } else if !query.isEmpty, let first = rows.indices.first(where: { target(at: $0) != nil }) {
            table.selectRowIndexes([first], byExtendingSelection: false)
            table.scrollRowToVisible(first)
        } else {
            table.deselectAll(nil)
            delegate?.sidebar(preview: nil, matches: [:])
        }
    }

    func reindex() {
        finder.invalidate()
        guard searching else { return }
        let kept = target(at: table.selectedRow)
        reindexing = true
        refill()
        if let kept, let row = rows.indices.first(where: { target(at: $0) == kept }) {
            table.selectRowIndexes([row], byExtendingSelection: false)
        } else if searching {
            table.deselectAll(nil)
            delegate?.sidebar(preview: nil, matches: [:])
        }
        reindexing = false
        if !searching {
            update()
        }
    }

    private func refill() {
        groups = query.isEmpty ? [] : finder.groups(for: query)
        let recent = query.isEmpty && fieldFocused ? finder.recent : []
        if !query.isEmpty {
            rows = groups.flatMap { [Row.group($0)] + $0.suggestions.map(Row.suggestion) }
        } else if !recent.isEmpty {
            rows = [.recent] + recent.map(Row.suggestion)
        } else {
            rows = Self.pages
        }
        table.refusesFirstResponder = searching
        table.allowsEmptySelection = true
        empty.show(query: query.isEmpty || !groups.isEmpty ? nil : query)
        table.reloadData()
    }

    func move(by step: Int) {
        guard searching else { return }
        var row = table.selectedRow
        repeat {
            row += step
        } while rows.indices.contains(row) && target(at: row) == nil
        guard rows.indices.contains(row) else { return }
        table.selectRowIndexes([row], byExtendingSelection: false)
        table.scrollRowToVisible(row)
    }

    func target(at row: Int) -> Target? {
        guard rows.indices.contains(row) else { return nil }
        switch rows[row] {
        case .group(let group) where group.isSelectable:
            return Target(place: group.place, entry: nil, choice: false)

        case .suggestion(let suggestion):
            return Target(
                place: suggestion.place, entry: suggestion.entry, choice: suggestion.matchedChoice)

        default:
            return nil
        }
    }

    func go(at row: Int) {
        guard let target = target(at: row) else { return }
        page = SettingsPage.all.firstIndex { $0.title == target.place.page } ?? page
        if let entry = target.entry {
            finder.visit(entry)
        }
        delegate?.sidebar(go: target, matches: matches)
    }

    @objc
    private func clicked() {
        guard searching, table.clickedRow >= 0 else { return }
        go(at: table.clickedRow)
    }

    @objc
    func clearRecent() {
        finder.clearRecent()
        update()
    }

    func forgetSelectedRecent() -> Bool {
        guard query.isEmpty, let entry = target(at: table.selectedRow)?.entry else { return false }
        finder.forget(entry)
        update()
        return true
    }
}
