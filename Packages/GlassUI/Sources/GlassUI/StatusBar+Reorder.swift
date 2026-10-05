import AppKit

extension StatusBar {
    func grab() {
        for (index, id) in pills.map(\.id).enumerated() {
            guard let view = views.first(where: { $0.identifier?.rawValue == id }),
                views.firstIndex(of: view) != index
            else { continue }
            stack.removeArrangedSubview(view)
            stack.insertArrangedSubview(view, at: index)
        }
        stack.layoutSubtreeIfNeeded()
        dragStart = shownIDs
    }

    func drag(_ id: String?, to point: NSPoint) -> NSDragOperation {
        guard !dragStart.isEmpty, let pill = views.first(where: { $0.identifier?.rawValue == id })
        else { return [] }
        drag(pill, to: point)
        return .move
    }

    private func drag(_ pill: StatusPill, to point: NSPoint) {
        let along = stack.convert(point, from: nil).x
        let index = views.count { $0 !== pill && $0.frame.midX < along }
        guard views.firstIndex(of: pill) != index else { return }
        stack.removeArrangedSubview(pill)
        stack.insertArrangedSubview(pill, at: index)
        stack.layoutSubtreeIfNeeded()
    }

    func drop(_ id: String) {
        let start = dragStart
        guard !start.isEmpty else { return }
        dragStart = []
        let order = shownIDs
        if order != start, let index = order.firstIndex(of: id) {
            onMove?(id, order.dropFirst(index + 1).first)
        }
        if shownIDs != pills.map(\.id) {
            rebuild()
        }
    }
}
