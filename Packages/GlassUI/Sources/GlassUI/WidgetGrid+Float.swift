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
            cells = WidgetGrid.cells(of: group, in: .grid)
            width = cells.map(\.columns.upperBound).max() ?? 1
            rows = cells.map(\.rows.upperBound).max() ?? 1
            column = min(spot.column, max(WidgetGrid.columns - width, 0))
            row = min(spot.row, max(Spot.shelfRows - rows, 0))
        }
    }

    static var sideWidth: CGFloat {
        railWidth(columns: railColumns.widest)
    }

    static func railWidth(columns: Int) -> CGFloat {
        extent(of: columns, unit: rowHeight, gap: gap)
    }

    static func railRows(of panel: CGRect) -> Int {
        max(Int((panel.height + gap) / (rowHeight + gap)), 1)
    }

    static func rows(of group: [Widget]) -> Int {
        group.reduce(0) { $0 + $1.size.rows }
    }

    static func shelfRows(of placed: [Placed], on side: Side) -> Int {
        let shelf = Set(placed.map(\.spot)).filter { $0.side == side }
        return shelf.map { spot in
            let block = Block(of: placed.filter { $0.spot == spot }.map(\.widget), at: spot)
            return block.row + block.rows
        }
        .max() ?? 0
    }

    static func floatingFrames(of placed: [Placed], beside panel: CGRect) -> [CGRect] {
        var frames = Array(repeating: CGRect.zero, count: placed.count)
        for spot in Set(placed.map(\.spot)) where !Side.rails.contains(spot.side) {
            let indices = placed.indices.filter { placed[$0].spot == spot }
            let found = self.frames(of: indices.map { placed[$0].widget }, at: spot, beside: panel)
            for (index, frame) in zip(indices, found) {
                frames[index] = frame
            }
        }
        for side in Side.rails {
            let units = railUnits(of: placed, on: side)
            let starts = resolved(
                units.map { unit in
                    (unit.spot.row, rows(of: unit.indices.map { placed[$0].widget }))
                },
                within: railRows(of: panel))
            for (unit, start) in zip(units, starts) {
                let found = rail(
                    of: unit.indices.map { placed[$0].widget }, on: side, row: start,
                    beside: panel)
                for (index, frame) in zip(unit.indices, found) {
                    frames[index] = frame
                }
            }
        }
        return frames
    }

    private static func railUnits(
        of placed: [Placed], on side: Side
    ) -> [(spot: Spot, indices: [Int])] {
        let indices = placed.indices.filter { placed[$0].spot.side == side }
        return Dictionary(grouping: indices) { placed[$0].spot }
            .sorted { $0.key < $1.key }
            .map { (spot: $0.key, indices: $0.value) }
    }

    static func frames(of group: [Widget], at spot: Spot, beside panel: CGRect) -> [CGRect] {
        switch spot.side {
        case .panel: []
        case .above, .below: shelf(group, at: spot, over: panel)

        case .left, .right:
            rail(
                of: group, on: spot.side,
                row: min(spot.row, max(railRows(of: panel) - rows(of: group), 0)), beside: panel)
        }
    }

    static func cellWidth(of panel: CGRect) -> CGFloat {
        (panel.width - CGFloat(columns - 1) * gap) / CGFloat(columns)
    }

    static func resolved(_ requests: [(row: Int, rows: Int)], within available: Int) -> [Int] {
        var starts: [Int] = []
        var end = 0
        for request in requests {
            starts.append(max(request.row, end))
            end = starts.last.map { $0 + request.rows } ?? end
        }
        var limit = available
        for index in starts.indices.reversed() {
            starts[index] = max(min(starts[index], limit - requests[index].rows), 0)
            limit = starts[index]
        }
        return starts
    }

    private static func shelf(_ group: [Widget], at spot: Spot, over panel: CGRect) -> [CGRect] {
        let step = rowHeight + gap
        let width = cellWidth(of: panel)
        let block = Block(of: group, at: spot)
        return block.cells.map { cell in
            let column = CGFloat(block.column + cell.columns.lowerBound)
            let height = extent(of: cell.rows.count, unit: rowHeight, gap: gap)
            let bottom =
                spot.side == .above
                ? panel.maxY + lift + CGFloat(block.row + block.rows - cell.rows.upperBound) * step
                : panel.minY - lift - CGFloat(block.row + cell.rows.lowerBound) * step - height
            return CGRect(
                x: panel.minX + column * (width + gap), y: bottom,
                width: extent(of: cell.columns.count, unit: width, gap: gap), height: height)
        }
    }

    private static func rail(
        of group: [Widget], on side: Side, row: Int, beside panel: CGRect
    ) -> [CGRect] {
        var top = panel.maxY - CGFloat(row) * (rowHeight + gap)
        return group.map { widget in
            let size = widget.railSize
            let width = railWidth(columns: size.columns)
            let height = extent(of: size.rows, unit: rowHeight, gap: gap)
            top -= height
            defer { top -= gap }
            return CGRect(
                x: side == .left ? panel.minX - sideGap - width : panel.maxX + sideGap, y: top,
                width: width, height: height)
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
