import AppKit

extension ResultList {
    private static let rowsBeforeEnd = 5

    func loadMoreIfNearEnd() {
        guard !loadingMore, sections.contains(where: \.hasMore) else { return }
        let lowest = max(NSMaxRange(table.rows(in: table.visibleRect)), table.selectedRow + 1)
        guard lowest + Self.rowsBeforeEnd >= rows.count else { return }
        loadingMore = true
        onNearEnd?()
    }

    func takeGrownSelection() -> String? {
        defer { loadingMore = false }
        return loadingMore ? selectedItem?.id : nil
    }

    func select(keeping kept: String?, scrolling: Bool) {
        let keptRow = kept.flatMap { id in rows.firstIndex { $0.itemID == id } }
        let preferred = rows.firstIndex(where: \.prefersSelection)
        if let row = keptRow ?? preferred ?? rows.firstIndex(where: \.isItem) {
            table.selectRowIndexes([row], byExtendingSelection: false)
        }
        guard scrolling || keptRow == nil else { return }
        reveal(keptRow ?? preferred ?? 0, context: keptRow == nil ? [0] : [], animated: false)
    }
}
