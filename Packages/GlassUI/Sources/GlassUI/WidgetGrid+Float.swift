import AppKit

extension WidgetGrid {
    typealias Placed = (widget: Widget, spot: Spot)

    private static let shelf: [Spot] = [.aboveLeft, .aboveCentre, .aboveRight]
    private static let anchors: [Anchor] = [.start, .middle, .end]
    private static let half: CGFloat = 0.5

    static func shelfRows(of placed: [Placed]) -> Int {
        shelf.map { spot in rowCount(of: placed.filter { $0.spot == spot }.map(\.widget)) }.max()
            ?? 0
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
        let width = (panel.width - CGFloat(columns - 1) * floatingGap) / CGFloat(columns)
        return shelf.flatMap { spot in
            let indices = placed.indices.filter { placed[$0].spot == spot }
            let widgets = indices.map { placed[$0].widget }
            let cells = cells(of: widgets)
            let rows = rowCount(of: widgets)
            let free = CGFloat(columns - (cells.map(\.columns.upperBound).max() ?? 0))
            let offset: CGFloat =
                switch spot.anchor {
                case .start: 0
                case .middle: free * half
                case .end: free
                }
            return zip(indices, cells).map { index, cell in
                let column = offset + CGFloat(cell.columns.lowerBound)
                let frame = CGRect(
                    x: panel.minX + column * (width + floatingGap),
                    y: panel.maxY + lift + CGFloat(rows - cell.rows.upperBound) * step,
                    width: extent(of: cell.columns.count, size: width, gap: floatingGap),
                    height: extent(of: cell.rows.count, size: rowHeight, gap: floatingGap))
                return (index, frame)
            }
        }
    }

    private static func railFrames(of placed: [Placed], beside panel: CGRect) -> [(Int, CGRect)] {
        [Side.left, .right].flatMap { side in
            let left = side == .left ? panel.minX - sideGap - sideWidth : panel.maxX + sideGap
            return anchors.flatMap { anchor in
                let indices = placed.indices.filter { index in
                    placed[index].spot.side == side && placed[index].spot.anchor == anchor
                }
                let heights = indices.map { index in
                    extent(of: placed[index].widget.rows, size: rowHeight, gap: floatingGap)
                }
                let gaps = CGFloat(max(indices.count - 1, 0)) * floatingGap
                let height = heights.reduce(0, +) + gaps
                var bottom: CGFloat =
                    switch anchor {
                    case .start: panel.maxY
                    case .middle: panel.midY + height * half
                    case .end: panel.minY + height
                    }
                return zip(indices, heights).map { index, height in
                    bottom -= height
                    defer { bottom -= floatingGap }
                    return (index, CGRect(x: left, y: bottom, width: sideWidth, height: height))
                }
            }
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
