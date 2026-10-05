import AppKit

extension WidgetGrid {
    private static let reach: CGFloat = 160
    static let maxPanelRows = 2
    private static let maxShelfRows = 2
    private static let maxRailRows = 3
    private static let half: CGFloat = 0.5
    private static let slack: CGFloat = 0.5
    private static let railMargin: CGFloat = 40
    private static let captionRoom: CGFloat = 30
    private static let refusedWidth: CGFloat = 120
    private static let crossWeight: CGFloat = 2

    private static var cellSized: Widget {
        Widget(id: "", name: "", content: .loading(title: ""), action: "", spoken: "")
    }

    static func tallest(on side: Side) -> Int {
        switch side {
        case .panel: maxPanelRows
        case .above, .below: maxShelfRows
        case .left, .right: maxRailRows
        }
    }

    static func slots(for group: [Widget]) -> [Spot] {
        let block = Block(of: group, at: .aboveLeft)
        let rows = 0...max(Spot.shelfRows - block.rows, 0)
        let across = 0...max(columns - block.width, 0)
        let above = rows.flatMap { row in across.map { Spot.above(column: $0, row: row) } }
        let below = rows.flatMap { row in across.map { Spot.below(column: $0, row: row) } }
        return above + below
            + Side.rails.flatMap { side in (0..<Spot.stops).map { Spot.beside(side, row: $0) } }
    }

    static func anchorPoint(of spot: Spot, beside panel: CGRect) -> CGPoint {
        guard spot.side != .panel else { return CGPoint(x: panel.midX, y: panel.midY) }
        let cell = frames(of: [cellSized], at: spot, beside: panel).first ?? .zero
        return CGPoint(x: cell.midX, y: cell.midY)
    }

    static func fits(
        _ target: Spot, inPanel: [Placed], placed: [Placed], layout: Layout?, beside panel: CGRect
    ) -> Bool {
        let side = target.side
        guard
            placed.allSatisfy({ $0.spot.side != side || $0.widget.size.rows <= tallest(on: side) })
        else { return false }
        return switch side {
        case .panel: panelFits(inPanel, layout: layout)
        case .above, .below: shelfFits(placed, on: side, beside: panel)
        case .left, .right: railFits(placed, on: side, beside: panel)
        }
    }

    static func railsFrame(beside panel: CGRect) -> CGRect {
        let side = sideGap + sideWidth + railMargin
        let shelf = lift + extent(of: Spot.shelfRows, unit: rowHeight, gap: gap) + captionRoom
        return panel.insetBy(dx: -side, dy: -shelf)
    }

    private static func panelFits(_ inPanel: [Placed], layout: Layout?) -> Bool {
        let placements = inPanel.map { item in
            Placement(size: item.widget.size(in: layout), pin: item.spot.pin(in: layout))
        }
        let laid = cells(spanning: placements)
        let held = zip(placements, laid).allSatisfy { placement, cell in
            placement.pin.map { pin in cell.columns.lowerBound == pin.column && cell.row == pin.row
            }
                ?? true
        }
        return held && rowCount(of: laid) <= (layout == .strip ? 1 : maxPanelRows)
    }

    private static func shelfFits(_ placed: [Placed], on side: Side, beside panel: CGRect) -> Bool {
        let shelf = lift + extent(of: Spot.shelfRows, unit: rowHeight, gap: gap)
        let found = zip(placed, floatingFrames(of: placed, beside: panel))
            .filter { $0.0.spot.side == side }
            .map(\.1)
        let inside = found.allSatisfy { frame in
            side == .above
                ? frame.maxY <= panel.maxY + shelf + slack
                : frame.minY >= panel.minY - reach - slack
        }
        let apart = found.indices.allSatisfy { index in
            found[(index + 1)...].allSatisfy { other in
                !found[index].insetBy(dx: slack, dy: slack).intersects(other)
            }
        }
        return inside && apart
    }

    private static func railFits(_ placed: [Placed], on side: Side, beside panel: CGRect) -> Bool {
        let units = Dictionary(grouping: placed.filter { $0.spot.side == side }, by: \.spot)
        return units.values.reduce(0) { $0 + rows(of: $1.map(\.widget)) } <= railRows(of: panel)
    }

    func accepts(_ id: String, at target: Spot, before other: String?) -> Bool {
        let movable = listed.contains { $0.id == id } || incoming?.id == id
        return movable && accepts(unit(of: id), at: target, before: other)
    }

    func accepts(_ unit: [String], at target: Spot, before other: String?) -> Bool {
        let movers = members(unit)
        var all = widgets.filter { !unit.contains($0.id) }
        let taken = target != .panel && all.contains { spot(of: $0) == target }
        guard movers.count == unit.count, !movers.isEmpty, !taken else { return false }
        all.insert(
            contentsOf: movers,
            at: other.flatMap { next in all.firstIndex { $0.id == next } } ?? all.endIndex)
        return fits(all, checking: [target]) { unit.contains($0.id) ? target : self.spot(of: $0) }
    }

    func fits(_ all: [Widget], checking targets: [Spot], at spot: (Widget) -> Spot) -> Bool {
        guard let window = unsafe window else { return false }
        let spotted = all.map { ($0, spot($0)) }
        let placed = spotted.filter { $0.1.side != .panel }
        let inPanel = spotted.filter { $0.1.side == .panel }
        return targets.allSatisfy { target in
            Self.fits(
                target, inPanel: inPanel, placed: placed, layout: tileLayout,
                beside: window.frame)
        }
    }

    func landing(of id: String, near point: CGPoint, beside panel: CGRect) -> Spot? {
        let group = members(unit(of: id))
        guard let index = group.firstIndex(where: { $0.id == id }) else { return nil }
        let near = Self.nearest(group, at: index, to: point, beside: panel)
            .filter { $0.distance < Self.reach }
            .map(\.spot)
        return near.first { accepts(id, at: $0, before: nil) } ?? near.first
    }

    func neighbour(of index: Int, toward heading: Heading) -> Int? {
        guard let window = unsafe window, shown.indices.contains(index) else { return nil }
        let frames = tileFrames(in: window)
        let from = CGPoint(x: frames[index].midX, y: frames[index].midY)
        let scored = frames.indices.filter { $0 != index }.compactMap { other in
            let gap = CGPoint(x: frames[other].midX - from.x, y: frames[other].midY - from.y)
            let (along, across) =
                switch heading {
                case .right: (gap.x, gap.y)
                case .left: (-gap.x, gap.y)
                case .top: (gap.y, gap.x)
                case .bottom: (-gap.y, gap.x)
                }
            return along > Self.slack && abs(across) <= along
                ? (index: other, score: along + Self.crossWeight * abs(across)) : nil
        }
        return scored.min { $0.score < $1.score }?.index
    }

    func carry(_ tile: WidgetTile?) {
        source = tile
        carrying = true
        placeFloats()
    }

    @discardableResult
    func preview(moving id: String, to point: NSPoint) -> Bool {
        let arriving = incoming?.id == id
        guard let window = unsafe window, arriving || shown.contains(where: { $0.id == id })
        else { return false }
        dragged = id
        let visible = shown
        let hit = tileFrames(in: window).firstIndex { $0.contains(point) }.map { visible[$0] }
        let screen = window.convertPoint(toScreen: point)
        guard Self.railsFrame(beside: window.frame).contains(screen),
            let target = target(for: id, over: hit, at: screen, beside: window.frame)
        else {
            refused = nil
            moving = nil
            order = []
            return false
        }
        let home = arriving ? nil : home(of: id)
        if target == home, moving != nil {
            moving = nil
            order = []
        } else if target != home, target != moving {
            return move(id, to: target, before: target == .panel ? hit?.id : nil)
        }
        refused = nil
        reorder(id, at: point, in: window)
        return true
    }

    func tileFrames(in window: NSWindow) -> [NSRect] {
        frames(of: panelCells).map { convert($0, to: nil) }
            + Self.floatingFrames(of: placed, beside: window.frame).map(window.convertFromScreen)
    }

    func endDrag() {
        dragged = nil
        moving = nil
        refused = nil
        carrying = false
        source = nil
        order = []
        incoming = nil
    }

    func placeRails(beside window: NSWindow) {
        guard editing || carrying else {
            rails.orderOut(nil)
            return
        }
        let panel = window.frame
        let frame = Self.railsFrame(beside: panel)
        rails.setFrame(frame, display: false)
        if rails.parent !== window {
            window.addChildWindow(rails, ordered: .below)
        }
        let local = { (rect: CGRect) in rect.offsetBy(dx: -frame.minX, dy: -frame.minY) }
        let rows = Dictionary(
            uniqueKeysWithValues: Side.shelves.map { side in
                (side, max(1, Self.shelfRows(of: placed, on: side)))
            })
        var model = WidgetRailsView.Model()
        model.panel = local(panel)
        model.shelves = rows.mapValues { Self.extent(of: $0, unit: Self.rowHeight, gap: Self.gap) }
        model.pucks = pucks(beside: panel, rows: rows).map { point in
            CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
        }
        model.hot = moving?.side
        model.ghost = ghost(in: window).map { ghost in
            WidgetRailsView.Mark(spot: ghost.spot, frame: local(ghost.frame))
        }
        model.refused = refused.map { spot in
            let point = Self.anchorPoint(of: spot, beside: panel)
            let size = CGSize(width: Self.refusedWidth, height: Self.rowHeight)
            let rect = CGRect(
                x: point.x - size.width * Self.half, y: point.y - size.height * Self.half,
                width: size.width, height: size.height)
            return WidgetRailsView.Mark(spot: spot, frame: local(rect))
        }
        rails.board.model = model
    }

    private func pucks(beside panel: CGRect, rows: [Side: Int]) -> [CGPoint] {
        let taken = Self.floatingFrames(of: placed, beside: panel).map { frame in
            frame.insetBy(dx: -Self.gap * Self.half, dy: -Self.gap * Self.half)
        }
        return Self.slots(for: [Self.cellSized])
            .filter { $0.row < (rows[$0.side] ?? Self.railRows(of: panel)) }
            .map { Self.anchorPoint(of: $0, beside: panel) }
            .filter { point in !taken.contains { $0.contains(point) } }
    }

    private func target(
        for id: String, over hit: Widget?, at screen: CGPoint, beside panel: CGRect
    ) -> Spot? {
        if let hit {
            if unit(of: id).contains(hit.id) { return spot(of: hit) }
            if spot(of: hit).side == .panel { return .panel }
        }
        guard panel.contains(screen) else { return landing(of: id, near: screen, beside: panel) }
        return cell(for: id, at: screen) ?? .panel
    }

    private func cell(for id: String, at screen: CGPoint) -> Spot? {
        guard let window = unsafe window, tileLayout == .grid, let widget = members([id]).first,
            let slot = slot(
                at: convert(
                    window.convertFromScreen(CGRect(origin: screen, size: .zero)).origin, from: nil)
            )
        else { return nil }
        let size = widget.size(in: tileLayout)
        let column = min(slot.column, Self.columns - size.columns)
        let row = min(slot.row, Self.maxPanelRows - size.rows)
        let taken = Self.cells(spanning: panelPlacements(of: inPanel.filter { $0.id != id }))
        let free = !taken.contains { other in
            other.columns.overlaps(column..<column + size.columns)
                && other.rows.overlaps(row..<row + size.rows)
        }
        let spot = Spot.cell(column: column, row: row)
        return free && accepts(unit(of: id), at: spot, before: nil) ? spot : nil
    }

    private func ghost(in window: NSWindow) -> (spot: Spot, frame: CGRect)? {
        guard let dragged else { return nil }
        let spot = moving ?? home(of: dragged)
        if spot.side == .panel {
            guard moving != nil, let index = inPanel.firstIndex(where: { $0.id == dragged }) else {
                return nil
            }
            let frames = frames(of: panelCells)
            return (spot, window.convertToScreen(convert(frames[index], to: nil)))
        }
        let frames = Self.floatingFrames(of: placed, beside: window.frame)
        return placed.firstIndex { $0.widget.id == dragged }.map { (spot, frames[$0]) }
    }

    private func move(_ id: String, to target: Spot, before other: String?) -> Bool {
        guard accepts(id, at: target, before: other) else {
            refused = target
            return false
        }
        let unit = unit(of: id)
        var ids = shown.map(\.id).filter { !unit.contains($0) }
        ids.insert(contentsOf: unit, at: other.flatMap(ids.firstIndex) ?? ids.endIndex)
        refused = nil
        moving = target
        order = ids
        return true
    }

    private func reorder(_ id: String, at point: NSPoint, in window: NSWindow) {
        let visible = shown
        var ids = visible.map(\.id)
        guard let from = ids.firstIndex(of: id) else { return }
        let frames = tileFrames(in: window)
        let spot = spot(of: visible[from])
        let target = frames.indices.first { index in
            frames[index].contains(point) && self.spot(of: visible[index]) == spot
        }
        if let target, target != from {
            ids.remove(at: from)
            ids.insert(id, at: target)
        }
        order = ids
    }
}
