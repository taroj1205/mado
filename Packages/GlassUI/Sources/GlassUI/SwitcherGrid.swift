import CoreGraphics

struct SwitcherGrid: Equatable {
    static let padding: CGFloat = 14
    static let gap: CGFloat = 10
    private static let edges = padding + padding

    let card: CGSize
    let columns: Int
    let rows: Int

    var size: CGSize {
        CGSize(
            width: Self.span(columns, of: card.width) + Self.edges,
            height: Self.span(rows, of: card.height) + Self.edges)
    }

    init(count: Int, card: CGSize, fitting limit: CGSize) {
        self.card = card
        columns = max(1, min(count, Self.fit(card.width, in: limit.width)))
        let allRows = (count + columns - 1) / columns
        rows = max(1, min(allRows, Self.fit(card.height, in: limit.height)))
    }

    private static func span(_ cells: Int, of length: CGFloat) -> CGFloat {
        CGFloat(cells) * length + CGFloat(max(0, cells - 1)) * gap
    }

    private static func fit(_ length: CGFloat, in limit: CGFloat) -> Int {
        Int(((limit - edges + gap) / (length + gap)).rounded(.down))
    }

    func firstRow(showing index: Int, from first: Int) -> Int {
        let row = index / columns
        if row < first { return row }
        if row >= first + rows { return row - rows + 1 }
        return first
    }

    func index(_ index: Int, movedBy rowCount: Int, count: Int) -> Int {
        let target = min(index + rowCount * columns, count - 1)
        return target >= 0 && target / columns != index / columns ? target : index
    }

    func origin(of index: Int, firstRow: Int) -> CGPoint? {
        let row = index / columns - firstRow
        guard (0..<rows).contains(row) else { return nil }
        let column = index % columns
        return CGPoint(
            x: Self.padding + CGFloat(column) * (card.width + Self.gap),
            y: Self.padding + CGFloat(row) * (card.height + Self.gap))
    }
}
