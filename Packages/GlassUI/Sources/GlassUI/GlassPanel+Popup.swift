import AppKit

enum PopupPlacement {
    static func clamped(_ frame: NSRect, in bounds: NSRect) -> NSRect {
        var frame = frame
        frame.size.height = min(frame.height, bounds.height)
        frame.origin.x = max(bounds.minX, min(frame.minX, bounds.maxX - frame.width))
        frame.origin.y = max(bounds.minY, min(frame.minY, bounds.maxY - frame.height))
        return frame
    }

    static func frame(of size: NSSize, hangingFrom point: NSPoint, in bounds: NSRect) -> NSRect {
        let hanging = NSRect(
            x: point.x, y: point.y - size.height, width: size.width, height: size.height)
        return clamped(hanging, in: bounds)
    }

    static func frame(
        of size: NSSize, beside anchor: NSRect, gap: CGFloat, leftFirst: Bool, in bounds: NSRect
    ) -> NSRect {
        let right = anchor.maxX + gap
        let left = anchor.minX - gap - size.width
        let fitsRight = right + size.width <= bounds.maxX
        let fitsLeft = left >= bounds.minX
        let onLeft = leftFirst ? fitsLeft || !fitsRight : !fitsRight && fitsLeft
        let level = NSRect(
            x: onLeft ? left : right, y: anchor.maxY - size.height, width: size.width,
            height: size.height)
        return clamped(level, in: bounds)
    }
}

extension GlassPanel {
    static func popup(radius: CGFloat) -> GlassPanel {
        let panel = GlassPanel(kind: .hud, contentRect: .zero, shape: .rounded(radius))
        panel.ignoresMouseEvents = false
        panel.isReleasedWhenClosed = false
        return panel
    }

    func present(_ frame: NSRect, over window: NSWindow) {
        if self.frame != frame {
            setFrame(frame, display: true)
        }
        if parent !== window {
            window.addChildWindow(self, ordered: .above)
        }
    }

    func dismiss() {
        parent?.removeChildWindow(self)
        orderOut(nil)
    }
}
