import AppKit

extension WidgetGrid {
    typealias Cell = (rows: Range<Int>, columns: Range<Int>)
    typealias Size = (columns: Int, rows: Int)

    nonisolated static func cells(of widgets: [Widget]) -> [Cell] {
        cells(sized: widgets.map { ($0.span, $0.rows) })
    }

    nonisolated static func cells(sized sizes: [Size]) -> [Cell] {
        var taken = Set<Int>()
        var row = 0
        var column = 0
        return sizes.map { size in
            let width = min(size.columns, columns)
            let covered = { (top: Int, left: Int) in
                (top..<top + size.rows).flatMap { line in
                    (left..<left + width).map { line * columns + $0 }
                }
            }
            while column + width > columns || !taken.isDisjoint(with: covered(row, column)) {
                if column + width < columns {
                    column += 1
                } else {
                    row += 1
                    column = 0
                }
            }
            taken.formUnion(covered(row, column))
            defer { column += width }
            return (row..<row + size.rows, column..<column + width)
        }
    }

    nonisolated static func rowCount(of widgets: [Widget]) -> Int {
        cells(of: widgets).map(\.rows.upperBound).max() ?? 0
    }

    nonisolated static func extent(of count: Int, size: CGFloat, gap: CGFloat) -> CGFloat {
        CGFloat(count) * size + CGFloat(max(count - 1, 0)) * gap
    }

    func frames(of widgets: [Widget]) -> [NSRect] {
        let area = bounds.insetBy(dx: Self.inset, dy: 0)
        let gaps = CGFloat(Self.columns - 1) * Self.gap
        let width = (area.width - gaps) / CGFloat(Self.columns)
        return Self.cells(of: widgets).map { cell in
            NSRect(
                x: area.minX + CGFloat(cell.columns.lowerBound) * (width + Self.gap),
                y: Self.top + CGFloat(cell.rows.lowerBound) * (rowHeight + Self.gap),
                width: Self.extent(of: cell.columns.count, size: width, gap: Self.gap),
                height: Self.extent(of: cell.rows.count, size: rowHeight, gap: Self.gap))
        }
    }
}
