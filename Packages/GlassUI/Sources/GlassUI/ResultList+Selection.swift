import AppKit

extension ResultList {
    var hidesSelection: Bool {
        get { table.selectionHighlightStyle == .none }
        set { table.selectionHighlightStyle = newValue ? .none : .regular }
    }

    public func selectPrevious() {
        moveSelection(by: -1)
    }

    @discardableResult
    public func selectNext() -> Bool {
        moveSelection(by: 1)
    }

    @discardableResult
    private func moveSelection(by step: Int) -> Bool {
        var row = table.selectedRow + step
        while rows.indices.contains(row), !rows[row].isItem {
            row += step
        }
        guard rows.indices.contains(row) else { return false }
        table.selectRowIndexes([row], byExtendingSelection: false)
        table.scrollRowToVisible(rows[..<row].lastIndex(where: \.isItem).map { $0 + 1 } ?? 0)
        table.scrollRowToVisible(row)
        return true
    }
}
