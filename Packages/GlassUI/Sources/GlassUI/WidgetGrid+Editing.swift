import AppKit

extension WidgetGrid {
    private static let tilt: CGFloat = 0.6
    private static let alternate = 2

    func tilt(at index: Int) -> CGFloat {
        guard editing, !reducesMotion() else { return 0 }
        return index.isMultiple(of: Self.alternate) ? -Self.tilt : Self.tilt
    }

    func place(_ tile: WidgetTile, in frame: NSRect, tilt: CGFloat) {
        if tile.frameCenterRotation != 0 {
            tile.frameCenterRotation = 0
        }
        tile.frame = frame
        if tilt != 0 {
            tile.frameCenterRotation = tilt
        }
    }

    func preview(moving id: String, to point: NSPoint) {
        var ids = shown.map(\.id)
        guard let from = ids.firstIndex(of: id) else { return }
        dragged = id
        let frames = frames(spanning: shown.map(\.span))
        if let target = frames.firstIndex(where: { $0.contains(point) }), target != from {
            ids.remove(at: from)
            ids.insert(id, at: target)
        }
        order = ids
    }

    func endDrag() {
        dragged = nil
        order = []
        incoming = nil
    }
}
