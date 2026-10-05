import AppKit

final class EmojiCollection: NSCollectionView {
    private static let doubleClick = 2

    var onDoubleClick: (() -> Void)?

    override var acceptsFirstResponder: Bool { false }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        let hit = indexPathForItem(at: convert(event.locationInWindow, from: nil))
        if event.clickCount == Self.doubleClick, let hit, selectionIndexPaths.contains(hit) {
            onDoubleClick?()
        }
    }
}
