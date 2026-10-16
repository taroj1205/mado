import AppKit

final class CameraGrip: NSView {
    private var start: (mouse: CGPoint, frame: CGRect)?

    override var mouseDownCanMoveWindow: Bool { false }

    override init(frame: NSRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        if #available(macOS 15, *) {
            addCursorRect(bounds, cursor: .frameResize(position: .bottomRight, directions: .all))
        } else {
            addCursorRect(bounds, cursor: .resizeLeftRight)
        }
    }

    override func mouseDown(with _: NSEvent) {
        guard let window = unsafe window else { return }
        start = (NSEvent.mouseLocation, window.frame)
    }

    override func mouseDragged(with _: NSEvent) {
        guard let window = unsafe window, let start else { return }
        let delta = NSEvent.mouseLocation.x - start.mouse.x
        window.setFrame(CameraGeometry.resized(start.frame, widening: delta), display: true)
    }

    override func mouseUp(with _: NSEvent) {
        start = nil
    }
}
