import AppKit

extension WidgetGrid {
    typealias Placed = (widget: Widget, spot: Spot)

    private static let shelf: [Spot] = [.aboveLeft, .aboveCentre, .aboveRight]
    private static let anchors: [Anchor] = [.start, .middle, .end]
    private static let half: CGFloat = 0.5

    static func shelfRows(of placed: [Placed]) -> Int {
        shelf.map { spot in rows(of: placed.filter { $0.spot == spot }) }.max() ?? 0
    }

    static func floatingFrames(of placed: [Placed], beside panel: CGRect) -> [CGRect] {
        var frames = Array(repeating: CGRect.zero, count: placed.count)
        let found = shelfFrames(of: placed, over: panel) + railFrames(of: placed, beside: panel)
        for (index, frame) in found {
            frames[index] = frame
        }
        return frames
    }

    private static func shelfFrames(of placed: [Placed], over panel: CGRect) -> [(Int, CGRect)] {
        let step = rowHeight + floatingGap
        let rows = shelfRows(of: placed)
        let width = (panel.width - CGFloat(columns - 1) * floatingGap) / CGFloat(columns)
        return shelf.flatMap { spot in
            let indices = placed.indices.filter { placed[$0].spot == spot }
            let cells = cells(of: indices.map { placed[$0].widget })
            let free = CGFloat(columns - (cells.map(\.columns.upperBound).max() ?? 0))
            let offset: CGFloat =
                switch spot.anchor {
                case .start: 0
                case .middle: free * half
                case .end: free
                }
            let drop = rows - (cells.last.map { $0.row + 1 } ?? 0)
            return zip(indices, cells).map { index, cell in
                let column = offset + CGFloat(cell.columns.lowerBound)
                let row = CGFloat(rows - 1 - drop - cell.row)
                let frame = CGRect(
                    x: panel.minX + column * (width + floatingGap),
                    y: panel.maxY + lift + row * step,
                    width: CGFloat(cell.columns.count) * (width + floatingGap) - floatingGap,
                    height: rowHeight)
                return (index, frame)
            }
        }
    }

    private static func railFrames(of placed: [Placed], beside panel: CGRect) -> [(Int, CGRect)] {
        let step = rowHeight + floatingGap
        return [Side.left, .right].flatMap { side in
            let left = side == .left ? panel.minX - sideGap - sideWidth : panel.maxX + sideGap
            return anchors.flatMap { anchor in
                let indices = placed.indices.filter { index in
                    placed[index].spot.side == side && placed[index].spot.anchor == anchor
                }
                let height = CGFloat(indices.count) * step - floatingGap
                let top =
                    switch anchor {
                    case .start: panel.maxY
                    case .middle: panel.midY + height * half
                    case .end: panel.minY + height
                    }
                return indices.enumerated().map { position, index in
                    let frame = CGRect(
                        x: left, y: top - rowHeight - CGFloat(position) * step, width: sideWidth,
                        height: rowHeight)
                    return (index, frame)
                }
            }
        }
    }

    private static func rows(of placed: [Placed]) -> Int {
        cells(of: placed.map(\.widget)).last.map { $0.row + 1 } ?? 0
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
        for (float, (frame, item)) in zip(floats, zip(frames, placed)) {
            let margin = editing ? -WidgetFloatFrame.margin : 0
            float.setFrame(frame.insetBy(dx: margin, dy: margin), display: false)
            float.alphaValue = item.widget.id == dragged ? 0 : 1
            if float.parent !== window {
                window.addChildWindow(float, ordered: .above)
            }
        }
    }
}
