import AppKit

extension WidgetGrid {
    private static let reach: CGFloat = 160
    private static let maxPanelRows = 2
    private static let half: CGFloat = 0.5
    private static let slack: CGFloat = 0.5
    private static let railMargin: CGFloat = 40
    private static let shelfRoom = 3
    private static let captionRoom: CGFloat = 30
    private static let refusedWidth: CGFloat = 120

    static func nearestSpot(to point: CGPoint, beside panel: CGRect) -> Spot? {
        if panel.contains(point) { return .panel }
        let distances = Spot.allCases.dropFirst().map { spot in
            let anchor = anchorPoint(of: spot, beside: panel)
            return (spot: spot, distance: hypot(anchor.x - point.x, anchor.y - point.y))
        }
        return distances.filter { $0.distance < reach }.min { $0.distance < $1.distance }?.spot
    }

    static func anchorPoint(of spot: Spot, beside panel: CGRect) -> CGPoint {
        let cell = (panel.width - CGFloat(columns - 1) * floatingGap) / CGFloat(columns)
        let rail = sideGap + sideWidth * half
        let tile = rowHeight * half
        let along = { (start: CGFloat, middle: CGFloat, end: CGFloat) in
            switch spot.anchor {
            case .start: start
            case .middle: middle
            case .end: end
            }
        }
        return switch spot.side {
        case .panel: CGPoint(x: panel.midX, y: panel.midY)

        case .above:
            CGPoint(
                x: along(panel.minX + cell * half, panel.midX, panel.maxX - cell * half),
                y: panel.maxY + lift + tile)

        case .left, .right:
            CGPoint(
                x: spot.side == .left ? panel.minX - rail : panel.maxX + rail,
                y: along(panel.maxY - tile, panel.midY, panel.minY + tile))
        }
    }

    static func railsFrame(beside panel: CGRect) -> CGRect {
        let side = sideGap + sideWidth + railMargin
        let top = lift + CGFloat(shelfRoom) * (rowHeight + floatingGap) + captionRoom
        var frame = panel.insetBy(dx: -side, dy: -railMargin)
        frame.size.height += top - railMargin
        return frame
    }

    func carry(_ tile: WidgetTile?) {
        source = tile
        carrying = true
        placeFloats()
    }

    @discardableResult
    func preview(moving id: String, to point: NSPoint) -> Bool {
        guard let window = unsafe window, shown.contains(where: { $0.id == id }) else {
            return false
        }
        dragged = id
        let visible = shown
        let hit = tileFrames(in: window).firstIndex { $0.contains(point) }.map { visible[$0] }
        let screen = window.convertPoint(toScreen: point)
        guard
            let target = hit.map(spot) ?? Self.nearestSpot(to: screen, beside: window.frame)
        else {
            refused = nil
            return false
        }
        let home = home(of: id)
        if target == home, moving != nil {
            moving = nil
            order = []
        } else if target != home, target != moving {
            return move(id, to: target, before: hit?.id, beside: window.frame)
        }
        refused = nil
        return reorder(id, at: point, in: window)
    }

    func tileFrames(in window: NSWindow) -> [NSRect] {
        frames(spanning: inPanel.map(\.span)).map { convert($0, to: nil) }
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
        let taken = Set(placed.map(\.spot))
        let rows = CGFloat(max(1, Self.shelfRows(of: placed)))
        var model = WidgetRailsView.Model()
        model.panel = local(panel)
        model.shelf = rows * Self.rowHeight + (rows - 1) * Self.floatingGap
        model.pucks = Spot.allCases.dropFirst().filter { !taken.contains($0) }.map { spot in
            let point = Self.anchorPoint(of: spot, beside: panel)
            return CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
        }
        model.hot = moving?.side
        model.ghost = moving.flatMap { spot in
            ghost(in: window).map { WidgetRailsView.Mark(spot: spot, frame: local($0)) }
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

    private func ghost(in window: NSWindow) -> CGRect? {
        guard let moving, let dragged else { return nil }
        if moving == .panel {
            guard let index = inPanel.firstIndex(where: { $0.id == dragged }) else { return nil }
            let frames = frames(spanning: inPanel.map(\.span))
            return window.convertToScreen(convert(frames[index], to: nil))
        }
        let frames = Self.floatingFrames(of: placed, beside: window.frame)
        return placed.firstIndex { $0.widget.id == dragged }.map { frames[$0] }
    }

    private func move(
        _ id: String, to target: Spot, before other: String?, beside panel: CGRect
    ) -> Bool {
        let previous = (moving, order)
        var ids = shown.map(\.id).filter { $0 != id }
        ids.insert(id, at: other.flatMap(ids.firstIndex) ?? ids.endIndex)
        moving = target
        order = ids
        guard fits(target, beside: panel) else {
            (moving, order) = previous
            refused = target
            return false
        }
        refused = nil
        return true
    }

    private func reorder(_ id: String, at point: NSPoint, in window: NSWindow) -> Bool {
        let visible = shown
        var ids = visible.map(\.id)
        guard let from = ids.firstIndex(of: id) else { return false }
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
        return target != nil
    }

    private func fits(_ target: Spot, beside panel: CGRect) -> Bool {
        if target == .panel {
            let rows = Self.cells(spanning: inPanel.map(\.span)).last.map { $0.row + 1 } ?? 0
            return layoutInUse != .grid || rows <= Self.maxPanelRows
        }
        let side = target.side
        let frames = zip(placed, Self.floatingFrames(of: placed, beside: panel))
            .filter { $0.0.spot.side == side }
            .map(\.1)
        let inside = frames.allSatisfy { frame in
            side == .above
                || (frame.minY >= panel.minY - Self.slack && frame.maxY <= panel.maxY + Self.slack)
        }
        let apart = frames.indices.allSatisfy { index in
            frames[(index + 1)...].allSatisfy { other in
                !frames[index].insetBy(dx: Self.slack, dy: Self.slack).intersects(other)
            }
        }
        return inside && apart
    }
}
