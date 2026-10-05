import AppKit

extension WidgetGrid {
    nonisolated static func cells(of widgets: [Widget]) -> [(row: Int, columns: Range<Int>)] {
        cells(spanning: widgets.map(\.span))
    }

    nonisolated static func cells(spanning spans: [Int]) -> [(row: Int, columns: Range<Int>)] {
        var row = 0
        var column = 0
        return spans.map { span in
            if column + span > columns {
                row += 1
                column = 0
            }
            defer { column += span }
            return (row, column..<column + span)
        }
    }

    func frames(spanning spans: [Int]) -> [NSRect] {
        let area = bounds.insetBy(dx: Self.inset, dy: 0)
        let gaps = CGFloat(Self.columns - 1) * Self.gap
        let width = (area.width - gaps) / CGFloat(Self.columns)
        return Self.cells(spanning: spans).map { cell in
            NSRect(
                x: area.minX + CGFloat(cell.columns.lowerBound) * (width + Self.gap),
                y: Self.top + CGFloat(cell.row) * (rowHeight + Self.gap),
                width: CGFloat(cell.columns.count) * (width + Self.gap) - Self.gap,
                height: rowHeight)
        }
    }
}
