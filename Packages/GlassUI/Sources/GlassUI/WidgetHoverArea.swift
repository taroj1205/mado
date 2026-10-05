import AppKit

final class WidgetHoverArea: NSView {
    var onChange: ((Bool) -> Void)?

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self))
    }

    override func mouseEntered(with _: NSEvent) {
        onChange?(true)
    }

    override func mouseExited(with _: NSEvent) {
        onChange?(false)
    }
}
