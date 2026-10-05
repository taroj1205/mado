import AppKit

extension WidgetGrid {
    private static let reach: CGFloat = 160
    private static let maxPanelRows = 2
    private static let half: CGFloat = 0.5
    private static let slack: CGFloat = 0.5
    private static let railMargin: CGFloat = 40
    private static let captionRoom: CGFloat = 30
    private static let refusedWidth: CGFloat = 120
    private static let crossWeight: CGFloat = 2

    private static var cellSized: Widget {
        Widget(id: "", name: "", content: .loading(title: ""), action: "", spoken: "")
    }

    static func slots(for group: [Widget]) -> [Spot] {
        let block = Block(of: group, at: .aboveLeft)
        let above = (0...max(Spot.rowsAbove - block.rows, 0)).flatMap { row in
            (0...max(columns - block.width, 0)).map { Spot.above(column: $0, row: row) }
        }
        return above
            + Side.rails.flatMap { side in (0..<Spot.stops).map { Spot.beside(side, row: $0) } }
    }

    static func anchorPoint(of spot: Spot, beside panel: CGRect) -> CGPoint {
        guard spot.side != .panel else { return CGPoint(x: panel.midX, y: panel.midY) }
        let cell = frames(of: [cellSized], at: spot, beside: panel).first ?? .zero
        return CGPoint(x: cell.midX, y: cell.midY)
    }

    static func fits(
        _ target: Spot, inPanel: [Widget], placed: [Placed], layout: Layout?, beside panel: CGRect
    ) -> Bool {
        if target == .panel {
            let tiles = layout == .strip ? inPanel.filter { !$0.isTall } : inPanel
            return rowCount(of: tiles) <= (layout == .strip ? 1 : maxPanelRows)
        }
        let side = target.side
        let top =
            panel.maxY + lift + CGFloat(Spot.rowsAbove) * (rowHeight + floatingGap) - floatingGap
        let frames = zip(placed, floatingFrames(of: placed, beside: panel))
            .filter { $0.0.spot.side == side }
            .map(\.1)
        let inside = frames.allSatisfy { frame in
            side == .above
                ? frame.maxY <= top + slack
                : frame.minY >= panel.minY - slack && frame.maxY <= panel.maxY + slack
        }
        let apart = frames.indices.allSatisfy { index in
            frames[(index + 1)...].allSatisfy { other in
                !frames[index].insetBy(dx: slack, dy: slack).intersects(other)
            }
        }
        return inside && apart
    }

    static func railsFrame(beside panel: CGRect) -> CGRect {
        let side = sideGap + sideWidth + railMargin
        let top =
            lift + CGFloat(Spot.rowsAbove) * (rowHeight + floatingGap) + captionRoom
        var frame = panel.insetBy(dx: -side, dy: -railMargin)
        frame.size.height += top - railMargin
        return frame
    }

    func accepts(_ id: String, at target: Spot, before other: String?) -> Bool {
        let movable = listed.contains { $0.id == id } || incoming?.id == id
        return movable && accepts(unit(of: id), at: target, before: other)
    }

    func accepts(_ unit: [String], at target: Spot, before other: String?) -> Bool {
        let movers = members(unit)
        var all = widgets.filter { !unit.contains($0.id) }
        let taken = target != .panel && all.contains { spot(of: $0) == target }
        let tallInStrip =
            target == .panel && tileLayout == .strip && movers.contains(where: \.isTall)
        guard movers.count == unit.count, !movers.isEmpty, !taken, !tallInStrip else {
            return false
        }
        all.insert(
            contentsOf: movers,
            at: other.flatMap { next in all.firstIndex { $0.id == next } } ?? all.endIndex)
        return fits(all, checking: [target]) { unit.contains($0.id) ? target : self.spot(of: $0) }
    }

    func fits(_ all: [Widget], checking targets: [Spot], at spot: (Widget) -> Spot) -> Bool {
        guard let window = unsafe window else { return false }
        let placed = all.compactMap { widget -> Placed? in
            let found = spot(widget)
            return found == .panel ? nil : (widget, found)
        }
        let inPanel = all.filter { spot($0) == .panel }
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
        frames(of: inPanel).map { convert($0, to: nil) }
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
        let rows = CGFloat(max(1, Self.shelfRows(of: placed)))
        var model = WidgetRailsView.Model()
        model.panel = local(panel)
        model.shelf = rows * Self.rowHeight + (rows - 1) * Self.floatingGap
        model.pucks = pucks(beside: panel, rows: Int(rows)).map { point in
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

    private func pucks(beside panel: CGRect, rows: Int) -> [CGPoint] {
        let taken = Self.floatingFrames(of: placed, beside: panel).map { frame in
            frame.insetBy(dx: -Self.floatingGap * Self.half, dy: -Self.floatingGap * Self.half)
        }
        return Self.slots(for: [Self.cellSized])
            .filter { $0.side != .above || $0.row < rows }
            .map { Self.anchorPoint(of: $0, beside: panel) }
            .filter { point in !taken.contains { $0.contains(point) } }
    }

    private func target(
        for id: String, over hit: Widget?, at screen: CGPoint, beside panel: CGRect
    ) -> Spot? {
        if let hit, spot(of: hit) == .panel || unit(of: id).contains(hit.id) {
            return spot(of: hit)
        }
        return panel.contains(screen) ? .panel : landing(of: id, near: screen, beside: panel)
    }

    private func ghost(in window: NSWindow) -> (spot: Spot, frame: CGRect)? {
        guard let dragged else { return nil }
        let spot = moving ?? home(of: dragged)
        if spot == .panel {
            guard moving != nil, let index = inPanel.firstIndex(where: { $0.id == dragged }) else {
                return nil
            }
            let frames = frames(of: inPanel)
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
