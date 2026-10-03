import AppKit

extension ResultList {
    private static let glide: TimeInterval = 0.15

    var hidesSelection: Bool {
        get { table.selectionHighlightStyle == .none }
        set { table.selectionHighlightStyle = newValue ? .none : .regular }
    }

    @discardableResult
    public func selectPrevious() -> Bool {
        moveSelection(by: -1)
    }

    func selectFirst() {
        guard let row = rows.firstIndex(where: \.isItem) else { return }
        table.selectRowIndexes([row], byExtendingSelection: false)
        reveal(0, context: [], animated: true)
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
        let ahead = min(max(row + step, 0), rows.count - 1)
        let section = rows[..<row].lastIndex(where: \.isItem).map { $0 + 1 } ?? 0
        reveal(row, context: [ahead, section], animated: true)
        return true
    }

    func reveal(_ row: Int, context: [Int], animated: Bool) {
        let shown = contentView.bounds.origin
        let caughtUp = origin(revealing: [row], from: shown)
        if animated, caughtUp != shown {
            stopGliding()
            contentView.setBoundsOrigin(caughtUp)
        }
        let target = origin(revealing: context + [row], from: heading ?? caughtUp)
        glide(to: target, animated: animated)
    }

    private func origin(revealing revealed: [Int], from start: NSPoint) -> NSPoint {
        var target = NSRect(origin: start, size: contentView.bounds.size)
        for row in revealed {
            let rect = contentView.convert(table.rect(ofRow: row), from: table)
            if rect.minY < target.minY + contentInsets.top {
                target.origin.y = rect.minY - contentInsets.top
            } else if rect.maxY > target.maxY - contentInsets.bottom {
                target.origin.y = rect.maxY + contentInsets.bottom - target.height
            }
        }
        return contentView.constrainBoundsRect(target).origin
    }

    func stopGliding() {
        guard heading != nil else { return }
        heading = nil
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            contentView.animator().setBoundsOrigin(contentView.bounds.origin)
        }
    }

    private func glide(to origin: NSPoint, animated: Bool) {
        guard animated, !reducesMotion() else {
            stopGliding()
            contentView.setBoundsOrigin(origin)
            return
        }
        guard origin != heading ?? contentView.bounds.origin else { return }
        heading = origin
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.glide
            context.timingFunction = StatusBar.ease
            contentView.animator().setBoundsOrigin(origin)
        } completionHandler: {
            MainActor.assumeIsolated { [weak self] in
                if self?.heading == origin { self?.heading = nil }
            }
        }
    }
}
