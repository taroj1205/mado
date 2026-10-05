import AppKit

extension WidgetGrid {
    typealias Placed = (widget: Widget, spot: Spot)

    struct Block {
        let cells: [Cell]
        let width: Int
        let rows: Int
        let column: Int
        let row: Int

        init(of group: [Widget], at spot: Spot) {
            cells = WidgetGrid.cells(of: group)
            width = cells.map(\.columns.upperBound).max() ?? 1
            rows = max(WidgetGrid.rowCount(of: group), 1)
            column = min(spot.column, max(WidgetGrid.columns - width, 0))
            row = min(spot.row, max(Spot.rowsAbove - rows, 0))
        }
    }

    static func shelfRows(of placed: [Placed]) -> Int {
        let shelf = Set(placed.map(\.spot)).filter { $0.side == .above }
        return shelf.map { spot in
            let block = Block(of: placed.filter { $0.spot == spot }.map(\.widget), at: spot)
            return block.row + block.rows
        }
        .max() ?? 0
    }

    static func floatingFrames(of placed: [Placed], beside panel: CGRect) -> [CGRect] {
        var frames = Array(repeating: CGRect.zero, count: placed.count)
        for spot in Set(placed.map(\.spot)) {
            let indices = placed.indices.filter { placed[$0].spot == spot }
            let found = self.frames(of: indices.map { placed[$0].widget }, at: spot, beside: panel)
            for (index, frame) in zip(indices, found) {
                frames[index] = frame
            }
        }
        return frames
    }

    static func frames(of group: [Widget], at spot: Spot, beside panel: CGRect) -> [CGRect] {
        switch spot.side {
        case .panel: []
        case .above: shelf(group, at: spot, over: panel)
        case .left, .right: rail(group, at: spot, beside: panel)
        }
    }

    static func cellWidth(of panel: CGRect) -> CGFloat {
        (panel.width - CGFloat(columns - 1) * floatingGap) / CGFloat(columns)
    }

    private static func shelf(_ group: [Widget], at spot: Spot, over panel: CGRect) -> [CGRect] {
        let step = rowHeight + floatingGap
        let width = cellWidth(of: panel)
        let block = Block(of: group, at: spot)
        return block.cells.map { cell in
            let column = CGFloat(block.column + cell.columns.lowerBound)
            let row = CGFloat(block.row + block.rows - cell.rows.upperBound)
            return CGRect(
                x: panel.minX + column * (width + floatingGap), y: panel.maxY + lift + row * step,
                width: extent(of: cell.columns.count, size: width, gap: floatingGap),
                height: extent(of: cell.rows.count, size: rowHeight, gap: floatingGap))
        }
    }

    private static func rail(_ group: [Widget], at spot: Spot, beside panel: CGRect) -> [CGRect] {
        let left = spot.side == .left ? panel.minX - sideGap - sideWidth : panel.maxX + sideGap
        let heights = group.map { extent(of: $0.rows, size: rowHeight, gap: floatingGap) }
        let height = heights.reduce(0, +) + CGFloat(max(group.count - 1, 0)) * floatingGap
        let travel = max(panel.height - height, 0)
        var bottom = panel.maxY - travel * CGFloat(spot.row) / CGFloat(Spot.stops - 1)
        return heights.map { height in
            bottom -= height
            defer { bottom -= floatingGap }
            return CGRect(x: left, y: bottom, width: sideWidth, height: height)
        }
    }

    static func makeFloat(for tile: WidgetTile) -> GlassPanel {
        let panel = GlassPanel(kind: .hud, contentRect: .zero, shape: .rounded(WidgetTile.radius))
        panel.ignoresMouseEvents = false
        panel.glass.contentView = tile
        tile.registerForDraggedTypes([dragType])
        if tile.editing {
            panel.contentView = WidgetFloatFrame(glass: panel.glass, badge: tile.remove)
        }
        return panel
    }

    func placeFloats() {
        guard let window = unsafe window, !isHidden else {
            floats.forEach { $0.orderOut(nil) }
            rails.orderOut(nil)
            return
        }
        placeRails(beside: window)
        let placed = placed
        let frames = Self.floatingFrames(of: placed, beside: window.frame)
        let travelling = dragged.map(unit) ?? []
        for (float, (frame, item)) in zip(floats, zip(frames, placed)) {
            let margin = editing ? -WidgetFloatFrame.margin : 0
            float.setFrame(frame.insetBy(dx: margin, dy: margin), display: false)
            float.alphaValue = item.widget.id == dragged ? 0 : 1
            float.ignoresMouseEvents = travelling.contains(item.widget.id)
            if float.parent !== window {
                window.addChildWindow(float, ordered: .above)
            }
        }
    }
}
