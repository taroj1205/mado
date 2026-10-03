import AppKit

extension WidgetGrid {
    static func floatingFrames(
        _ layout: Layout, for widgets: [Widget], beside panel: CGRect
    ) -> [CGRect] {
        let step = rowHeight + floatingGap
        switch layout {
        case .above:
            let cells = cells(of: widgets)
            let rows = cells.last.map { $0.row + 1 } ?? 0
            let area = panel.insetBy(dx: inset, dy: 0)
            let width = (area.width - CGFloat(columns - 1) * floatingGap) / CGFloat(columns)
            return cells.map { cell in
                CGRect(
                    x: area.minX + CGFloat(cell.columns.lowerBound) * (width + floatingGap),
                    y: panel.maxY + lift + CGFloat(rows - 1 - cell.row) * step,
                    width: CGFloat(cell.columns.count) * (width + floatingGap) - floatingGap,
                    height: rowHeight)
            }

        case .around:
            let left = (widgets.count + sides - 1) / sides
            return widgets.indices.map { index in
                let leftSide = index < left
                return CGRect(
                    x: leftSide ? panel.minX - sideGap - sideWidth : panel.maxX + sideGap,
                    y: panel.maxY - rowHeight - CGFloat(leftSide ? index : index - left) * step,
                    width: sideWidth, height: rowHeight)
            }

        case .grid, .strip:
            return []
        }
    }
}
