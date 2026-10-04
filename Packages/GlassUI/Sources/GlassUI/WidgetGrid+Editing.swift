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

    func makeTile(at index: Int) -> WidgetTile {
        let tile = WidgetTile(floating: floating)
        tile.editing = editing
        tile.onPress = { [weak self] in self?.onPress?(index) }
        tile.onSkip = { [weak self] skip in self?.onSkip?(index, skip) }
        tile.onRemove = { [weak self] in self?.onRemove?(index) }
        tile.onDrag = { [weak self] id, point, source in self?.onDrag?(id, point, source) ?? [] }
        tile.onDrop = { [weak self] id in self?.onDrop?(id) ?? false }
        tile.onDragEnd = { [weak self] in self?.onDragEnd?() }
        return tile
    }

    @discardableResult
    func preview(moving id: String, to point: NSPoint) -> Bool {
        var ids = shown.map(\.id)
        guard let from = ids.firstIndex(of: id), let window = unsafe window else { return false }
        dragged = id
        let frames =
            if floating, let layoutInUse {
                Self.floatingFrames(layoutInUse, for: shown, beside: window.frame)
                    .map(window.convertFromScreen)
            } else {
                frames(spanning: shown.map(\.span)).map { convert($0, to: nil) }
            }
        let target = frames.firstIndex { $0.contains(point) }
        if let target, target != from {
            ids.remove(at: from)
            ids.insert(id, at: target)
        }
        order = ids
        return target != nil
    }

    func endDrag() {
        dragged = nil
        order = []
        incoming = nil
    }
}
