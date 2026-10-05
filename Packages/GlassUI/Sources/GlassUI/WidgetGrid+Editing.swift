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

    func makeTile(at index: Int, floating: Bool) -> WidgetTile {
        let tile = WidgetTile(floating: floating)
        tile.editing = editing
        tile.onPress = { [weak self] in self?.onPress?(index) }
        tile.onExtend = { [weak self] in self?.onExtend?(index) }
        tile.onSkip = { [weak self] skip in self?.onSkip?(index, skip) }
        tile.onDay = { [weak self] query in self?.onDay?(query) }
        tile.onPage = { [weak self] page in self?.onPage?(index, page) }
        tile.onRemove = { [weak self] in self?.onRemove?(index) }
        tile.onResize = { [weak self] resize in self?.onResize?(index, resize) }
        tile.onDrag = { [weak self] id, point, source in self?.onDrag?(id, point, source) ?? [] }
        tile.onDrop = { [weak self] id in self?.onDrop?(id) ?? false }
        tile.onDragStart = { [weak self, weak tile] in self?.carry(tile) }
        tile.onDragEnd = { [weak self] in self?.onDragEnd?() }
        return tile
    }

    func highlight(_ index: Int?) {
        for (position, (tile, widget)) in zip(tiles, shown).enumerated() {
            tile.selected = position == index || picked.contains(widget.id)
        }
    }
}
