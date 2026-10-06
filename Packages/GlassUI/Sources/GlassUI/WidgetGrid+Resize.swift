import AppKit

extension WidgetGrid {
    typealias Change = (columns: Int, rows: Int)

    func stretch(_ id: String, by distance: CGSize) {
        guard let window = unsafe window, let widget = supplied.first(where: { $0.id == id }),
            let start = pull?.start ?? currentSize(of: id)
        else { return }
        let step = step(of: id, in: window)
        let free = resizes(of: widget)
        let held = CGSize(
            width: free.contains(.horizontal) ? distance.width : 0,
            height: free.contains(.vertical) ? distance.height : 0)
        let change = (
            columns: Int((held.width / step.width).rounded()),
            rows: Int((held.height / step.height).rounded())
        )
        trial = fitted(id, adding: change).map { [id: $0] } ?? [:]
        pull = Pull(id: id, start: start, distance: held)
    }

    func finishStretch(_ id: String) -> Size? {
        settling = pulledFrame.map { Settle(id: id, from: $0) }
        pulledFrame = nil
        defer { trial = [:] }
        pull = nil
        return trial[id]
    }

    func currentSize(of id: String) -> Size? {
        guard let widget = supplied.first(where: { $0.id == id }) else { return nil }
        let side = home(of: id).side
        return limited(
            sizes[id] ?? (side.isRail ? widget.railSize : widget.smallest), for: widget)
    }

    func fitted(_ id: String, adding change: Change) -> Size? {
        guard let widget = supplied.first(where: { $0.id == id }), let start = currentSize(of: id)
        else { return nil }
        let free = resizes(of: widget)
        let wanted = limited(
            Size(
                columns: start.columns + (free.contains(.horizontal) ? change.columns : 0),
                rows: start.rows + (free.contains(.vertical) ? change.rows : 0)),
            for: widget)
        return candidates(from: start, to: wanted).first { fits($0, for: id) }
    }

    func options(for id: String) -> [Size] {
        guard let widget = supplied.first(where: { $0.id == id }), let current = currentSize(of: id)
        else { return [] }
        let all =
            home(of: id).side.isRail
            ? (1...Self.tallest(on: .left)).map { Size(columns: current.columns, rows: $0) }
            : Size.named
        let tall = resizes(of: widget).contains(.vertical)
        return all.filter { size in
            limited(size, for: widget) == size && (tall || size.rows == current.rows)
                && (size == current || fits(size, for: id))
        }
    }

    private func fits(_ size: Size, for id: String) -> Bool {
        let all = widgets.map { other in
            var sized = other
            sized.resized = other.id == id ? size : sized.resized
            return sized
        }
        return fits(all, checking: [home(of: id)]) { self.home(of: $0.id) }
    }

    func limited(_ size: Size, for widget: Widget) -> Size {
        limited(size, for: widget, on: home(of: widget.id).side)
    }

    func range(of widget: Widget, on side: Side) -> (least: Size, most: Size) {
        let rail = side.isRail
        let least = Size(
            columns: rail ? Self.railColumns.narrowest : widget.smallest.columns,
            rows: widget.smallest.rows)
        let widest = rail ? Self.railColumns.widest : min(Self.columns, widget.largest.columns)
        let tallest = min(Self.tallest(on: side), widget.largest.rows)
        let most = Size(
            columns: max(widest, least.columns), rows: max(tallest, least.rows))
        return (least, most)
    }

    func limited(_ size: Size, for widget: Widget, on side: Side) -> Size {
        let range = range(of: widget, on: side)
        return Size(
            columns: min(max(size.columns, range.least.columns), range.most.columns),
            rows: min(max(size.rows, range.least.rows), range.most.rows))
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

    func step(of id: String, in window: NSWindow) -> CGSize {
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
