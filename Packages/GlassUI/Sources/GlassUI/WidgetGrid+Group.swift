import AppKit

extension WidgetGrid {
    static func nearest(
        _ group: [Widget], at index: Int, to point: CGPoint, beside panel: CGRect
    ) -> [(spot: Spot, distance: CGFloat)] {
        slots(for: group).enumerated()
            .map { order, spot in
                let frame = frames(of: group, at: spot, beside: panel)[index]
                return (spot, hypot(frame.midX - point.x, frame.midY - point.y), order)
            }
            .sorted { ($0.1, $0.2) < ($1.1, $1.2) }
            .map { (spot: $0.0, distance: $0.1) }
    }

    private static func spot(at frame: CGRect, on side: Side, beside panel: CGRect) -> Spot {
        let step = rowHeight + gap
        let column = Int(((frame.minX - panel.minX) / (cellWidth(of: panel) + gap)).rounded())
        switch side {
        case .above:
            return .above(
                column: column, row: Int(((frame.minY - panel.maxY - lift) / step).rounded()))

        case .below:
            return .below(
                column: column, row: Int(((panel.minY - lift - frame.maxY) / step).rounded()))

        case .left, .right, .panel:
            return .beside(side, row: Int(((panel.maxY - frame.maxY) / step).rounded()))
        }
    }

    func next(from id: String, toward heading: Heading) -> Spot? {
        let home = settled(home(of: id), for: id)
        var spot = home
        while let step = spot.step(toward: heading) {
            let landed = settled(step, for: id)
            if landed != home, accepts(id, at: landed, before: nil) { return landed }
            spot = step
        }
        return nil
    }

    func room(for ids: [String], near spot: Spot) -> Spot? {
        guard let window = unsafe window else { return nil }
        let group = members(ids)
        let origin = Self.anchorPoint(of: spot, beside: window.frame)
        return Self.nearest(group, at: 0, to: origin, beside: window.frame)
            .map(\.spot)
            .first { accepts(ids, at: $0, before: nil) }
    }

    func spread(_ id: String) -> [String: Spot] {
        let home = home(of: id)
        let group = widgets.filter { self.home(of: $0.id) == home }
        guard let window = unsafe window, home.side != .panel, group.count > 1 else { return [:] }
        let panel = window.frame
        var end = 0
        let spots = zip(group, Self.frames(of: group, at: home, beside: panel)).map { item in
            var spot = Self.spot(at: item.1, on: home.side, beside: panel)
            if home.side.isRail {
                spot = .beside(home.side, row: max(spot.row, end))
                end = spot.row + item.0.railSize.rows
            }
            return (item.0.id, spot)
        }
        let moved = Dictionary(uniqueKeysWithValues: spots)
        guard Set(moved.values).count == group.count,
            fits(widgets, checking: [home], at: { moved[$0.id] ?? self.home(of: $0.id) })
        else { return [:] }
        return moved
    }

    private func settled(_ spot: Spot, for id: String) -> Spot {
        guard spot.side.isShelf else { return spot }
        let block = Block(of: members(unit(of: id)), at: spot)
        return spot.side == .above
            ? .above(column: block.column, row: block.row)
            : .below(column: block.column, row: block.row)
    }
}
