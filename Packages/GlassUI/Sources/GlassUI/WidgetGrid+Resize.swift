import AppKit

extension WidgetGrid {
    typealias Change = (columns: Int, rows: Int)

    func stretch(_ id: String, by distance: CGSize) {
        guard let window = unsafe window else { return }
        let step = step(of: id, in: window)
        let change = (
            columns: Int((distance.width / step.width).rounded()),
            rows: Int((distance.height / step.height).rounded())
        )
        trial = fitted(id, adding: change).map { [id: $0] } ?? [:]
    }

    func finishStretch(_ id: String) -> Size? {
        defer { trial = [:] }
        return trial[id]
    }

    func fitted(_ id: String, adding change: Change) -> Size? {
        guard let widget = supplied.first(where: { $0.id == id }) else { return nil }
        let side = home(of: id).side
        let start = limited(
            sizes[id] ?? (side.isRail ? widget.railSize : widget.smallest), for: widget)
        let free = resizes(of: widget)
        let wanted = limited(
            Size(
                columns: start.columns + (free.contains(.horizontal) ? change.columns : 0),
                rows: start.rows + (free.contains(.vertical) ? change.rows : 0)),
            for: widget)
        return candidates(from: start, to: wanted).first { size in
            let all = widgets.map { other in
                var sized = other
                sized.resized = other.id == id ? size : sized.resized
                return sized
            }
            return fits(all, checking: [home(of: id)]) { self.home(of: $0.id) }
        }
    }

    func limited(_ size: Size, for widget: Widget) -> Size {
        let side = home(of: widget.id).side
        let range = side.isRail ? Self.railColumns : (widget.smallest.columns, Self.widest)
        return Size(
            columns: min(max(size.columns, range.0), range.1),
            rows: min(max(size.rows, widget.smallest.rows), Self.tallest(on: side)))
    }

    func resizes(of widget: Widget) -> Set<WidgetTile.Axis> {
        switch spot(of: widget).side {
        case .panel where tileLayout == .strip: [.horizontal]
        case .panel, .above, .below, .left, .right: [.horizontal, .vertical]
        }
    }

    private func candidates(from start: Size, to wanted: Size) -> [Size] {
        let columns = min(start.columns, wanted.columns)...max(start.columns, wanted.columns)
        let rows = min(start.rows, wanted.rows)...max(start.rows, wanted.rows)
        let distance = { (size: Size) in
            abs(size.columns - wanted.columns) + abs(size.rows - wanted.rows)
        }
        return columns.flatMap { column in rows.map { Size(columns: column, rows: $0) } }
            .filter { $0 != start }
            .sorted { (distance($0), $0.columns, $0.rows) < (distance($1), $1.columns, $1.rows) }
    }

    private func step(of id: String, in window: NSWindow) -> CGSize {
        let side = home(of: id).side
        guard side == .panel else {
            let width = side.isRail ? Self.rowHeight : Self.cellWidth(of: window.frame)
            return CGSize(width: width + Self.gap, height: Self.rowHeight + Self.gap)
        }
        let area = bounds.width - Self.inset - Self.inset - CGFloat(Self.columns - 1) * Self.gap
        return CGSize(
            width: area / CGFloat(Self.columns) + Self.gap, height: rowHeight + Self.gap)
    }
}
