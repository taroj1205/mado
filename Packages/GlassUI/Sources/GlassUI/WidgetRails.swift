import AppKit

final class WidgetRails: NSPanel {
    let board = WidgetRailsView()

    init() {
        super.init(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
            defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = board
        board.registerForDraggedTypes([WidgetGrid.dragType])
    }
}
