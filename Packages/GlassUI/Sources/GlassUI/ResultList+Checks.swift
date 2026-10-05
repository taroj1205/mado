import AppKit

extension ResultList {
    public func clearChecks() {
        guard !checked.isEmpty else { return }
        checked = []
        checksChanged()
    }

    func pruneChecks() -> Bool {
        let present = Set(
            rows.compactMap { row -> String? in
                if case .item(let item) = row, item.isCheckable { item.id } else { nil }
            })
        let kept = checked.filter(present.contains)
        let changed = kept.count != checked.count
        checked = kept
        return changed
    }

    func checkClickedRow() {
        let row = table.clickedRow
        guard NSApp.currentEvent?.modifierFlags.contains(.command) == true,
            rows.indices.contains(row),
            case .item(let item) = rows[row], item.isCheckable
        else { return }
        if checked.isEmpty, let before = cursor.previous, before != item.id, isCheckable(before) {
            checked = [before]
        }
        toggle(item.id)
        checksChanged()
    }

    @discardableResult
    func extendChecks(by step: Int) -> Bool {
        guard let left = selectedItem, left.isCheckable else { return false }
        guard moveSelection(by: step), let entered = selectedItem else { return true }
        if checked.contains(entered.id) {
            checked.removeAll { $0 == left.id }
        } else {
            if !checked.contains(left.id) { checked.append(left.id) }
            if entered.isCheckable { checked.append(entered.id) }
        }
        checksChanged()
        return true
    }

    private func isCheckable(_ id: String) -> Bool {
        rows.contains { row in
            if case .item(let item) = row { item.id == id && item.isCheckable } else { false }
        }
    }

    private func toggle(_ id: String) {
        if let index = checked.firstIndex(of: id) {
            checked.remove(at: index)
        } else {
            checked.append(id)
        }
    }

    private func checksChanged() {
        table.reloadData(forRowIndexes: IndexSet(integersIn: 0..<rows.count), columnIndexes: [0])
        table.enumerateAvailableRowViews { rowView, row in
            guard let view = rowView as? ResultRowView, rows.indices.contains(row) else { return }
            view.isChecked = rows[row].itemID.map(checked.contains) ?? false
        }
        notifyChecks()
    }

    func notifyChecks() {
        onChecksChanged?()
        onCheck?(checked)
    }
}
