import AppKit
import SearchKit

extension SettingsSidebar: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in _: NSTableView) -> Int {
        rows.count
    }

    func tableView(_: NSTableView, heightOfRow row: Int) -> CGFloat {
        switch rows[row] {
        case .page:
            Self.rowHeight

        case .group, .recent:
            SettingsGroupCell.height + (row == 0 ? 0 : SettingsGroupCell.gap)

        case .suggestion(let suggestion):
            SettingsSuggestionCell.height(of: suggestion, width: table.bounds.width)
        }
    }

    func tableView(_: NSTableView, rowViewForRow _: Int) -> NSTableRowView? {
        SettingsSidebarRow(accent: searching)
    }

    func tableView(_: NSTableView, shouldSelectRow row: Int) -> Bool {
        !searching || target(at: row) != nil
    }

    func tableView(_: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        switch rows[row] {
        case .page(let index):
            let selected = row == table.selectedRow
            return SettingsPageCell(page: SettingsPage.all[index], selected: selected)

        case .group(let group):
            let cell = SettingsGroupCell(clearTarget: nil, clearAction: nil)
            let symbol = SettingsPage.all.first { $0.title == group.place.page }?.symbol ?? ""
            cell.show(group.title, symbol: symbol, clearable: false)
            return cell

        case .recent:
            let cell = SettingsGroupCell(clearTarget: self, clearAction: #selector(clearRecent))
            let title = SettingsSearch.Text(string: "Recent", matches: [])
            cell.show(title, symbol: Self.recentSymbol, clearable: true)
            return cell

        case .suggestion(let suggestion):
            let cell = SettingsSuggestionCell()
            let keycaps = query.isEmpty ? [] : finder.keycaps(for: suggestion.entry)
            cell.show(suggestion, keycaps: keycaps, width: table.bounds.width)
            return cell
        }
    }

    func tableView(_: NSTableView, typeSelectStringFor _: NSTableColumn?, row: Int) -> String? {
        guard case .page(let index) = rows[row] else { return nil }
        return SettingsPage.all[index].title
    }

    func tableViewSelectionDidChange(_: Notification) {
        guard !reindexing else { return }
        guard !searching else {
            previewSelection()
            return
        }
        let selected = table.selectedRow
        guard rows.indices.contains(selected), case .page(let index) = rows[selected] else {
            return
        }
        page = index
        delegate?.sidebar(picked: index)
        table.enumerateAvailableRowViews { rowView, row in
            (rowView.view(atColumn: 0) as? SettingsPageCell)?.selected = row == table.selectedRow
        }
    }

    func previewSelection() {
        delegate?.sidebar(preview: target(at: table.selectedRow), matches: matches)
        announce(row: table.selectedRow)
    }

    private func announce(row: Int) {
        guard rows.indices.contains(row) else { return }
        let spoken: String
        switch rows[row] {
        case .suggestion(let suggestion):
            spoken = suggestion.spoken

        case .group(let group):
            spoken = group.title.string

        default:
            return
        }
        unsafe NSAccessibility.post(
            element: table, notification: .announcementRequested,
            userInfo: [
                .announcement: spoken,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ])
    }
}
