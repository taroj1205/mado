import AppKit

extension WidgetGrid {
    struct Cell: Equatable {
        let columns: Range<Int>
        let rows: Range<Int>

        var row: Int { rows.lowerBound }
    }

    struct Placement {
        let size: Size
        var pin: (column: Int, row: Int)?
    }

    private var columnWidth: CGFloat {
        let gaps = CGFloat(Self.columns - 1) * Self.gap
        return (bounds.width - Self.inset - Self.inset - gaps) / CGFloat(Self.columns)
    }

    nonisolated static func cells(of widgets: [Widget], in layout: Layout?) -> [Cell] {
        cells(spanning: widgets.map { $0.size(in: layout) })
    }

    nonisolated static func cells(spanning sizes: [Size]) -> [Cell] {
        cells(spanning: sizes.map { Placement(size: $0) })
    }

    nonisolated static func cells(spanning placements: [Placement]) -> [Cell] {
        var taken: Set<Int> = []
        var placed = [Cell?](repeating: nil, count: placements.count)
        for (position, placement) in placements.enumerated() {
            guard let pin = placement.pin else { continue }
            let width = min(placement.size.columns, columns)
            let index = pin.row * columns + pin.column
            guard isFree(at: index, width: width, rows: placement.size.rows, taken: taken)
            else { continue }
            let cell = Cell(
                columns: pin.column..<pin.column + width,
                rows: pin.row..<pin.row + placement.size.rows)
            taken.formUnion(indices(of: cell))
            placed[position] = cell
        }
        var origin = 0
        return placements.indices.map { index in
            if let cell = placed[index] { return cell }
            let size = placements[index].size
            let width = min(size.columns, columns)
            var next = origin
            while !isFree(at: next, width: width, rows: size.rows, taken: taken) {
                next += 1
            }
            let (row, column) = next.quotientAndRemainder(dividingBy: columns)
            let cell = Cell(columns: column..<column + width, rows: row..<row + size.rows)
            taken.formUnion(indices(of: cell))
            origin = next + width
            return cell
        }
    }

    nonisolated static func rowCount(of cells: [Cell]) -> Int {
        cells.map(\.rows.upperBound).max() ?? 0
    }

    static func extent(of count: Int, unit: CGFloat, gap: CGFloat) -> CGFloat {
        CGFloat(count) * (unit + gap) - gap
    }

    nonisolated private static func indices(of cell: Cell) -> [Int] {
        cell.rows.flatMap { row in cell.columns.map { row * columns + $0 } }
    }

    nonisolated private static func isFree(
        at index: Int, width: Int, rows: Int, taken: Set<Int>
    ) -> Bool {
        let (row, column) = index.quotientAndRemainder(dividingBy: columns)
        guard column + width <= columns else { return false }
        return (row..<row + rows).allSatisfy { covered in
            (column..<column + width).allSatisfy { !taken.contains(covered * columns + $0) }
        }
    }

    func frames(of cells: [Cell]) -> [NSRect] {
        let width = columnWidth
        return cells.map { cell in
            NSRect(
                x: Self.inset + CGFloat(cell.columns.lowerBound) * (width + Self.gap),
                y: Self.top + CGFloat(cell.row) * (rowHeight + Self.gap),
                width: Self.extent(of: cell.columns.count, unit: width, gap: Self.gap),
                height: Self.extent(of: cell.rows.count, unit: rowHeight, gap: Self.gap))
        }
    }

    func slot(at point: NSPoint) -> (column: Int, row: Int)? {
        guard bounds.contains(point) else { return nil }
        let column = Int((point.x - Self.inset) / (columnWidth + Self.gap))
        let row = Int((point.y - Self.top) / (rowHeight + Self.gap))
        return (min(max(column, 0), Self.columns - 1), max(row, 0))
    }
}
