import AppKit

extension WidgetGrid {
    func showMenu(of index: Int?) {
        for (position, tile) in tiles.enumerated() {
            tile.menuOpen = position == index
        }
    }

    func pickUp(_ index: Int, grabbedAt grab: NSPoint) {
        unsafe window?.layoutIfNeeded()
        guard tiles.indices.contains(index), let window = unsafe tiles[index].window,
            let event = NSEvent.mouseEvent(
                with: .leftMouseDragged, location: window.mouseLocationOutsideOfEventStream,
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1,
                pressure: 1)
        else { return }
        window.layoutIfNeeded()
        beginsDrag(tiles[index], event, grab)
    }
}
