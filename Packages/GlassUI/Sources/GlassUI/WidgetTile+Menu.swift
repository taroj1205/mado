import AppKit

extension WidgetTile {
    private static let menuLead: CGFloat = 16
    private static let menuGap: CGFloat = 5
    private static let moreGap: CGFloat = 4
    private static let holdSlop: CGFloat = 4
    private static let fade: TimeInterval = 0.15

    var moreFrame: NSRect {
        let strip = month.isHidden || !month.isInteractive ? 0 : month.controlStrip
        let trailing = strip == 0 ? WidgetMoreButton.inset : Self.horizontal + strip + Self.moreGap
        return NSRect(
            x: bounds.maxX - trailing - WidgetMoreButton.size,
            y: bounds.maxY - WidgetMoreButton.inset - WidgetMoreButton.size,
            width: WidgetMoreButton.size, height: WidgetMoreButton.size)
    }

    var buttonAnchor: NSPoint {
        let corner = NSPoint(x: moreFrame.minX - Self.menuLead, y: moreFrame.minY - Self.menuGap)
        return unsafe window?.convertPoint(toScreen: convert(corner, to: nil)) ?? .zero
    }

    func arrangeMore() {
        more.isHidden = true
        addSubview(more)
        addTrackingArea(
            NSTrackingArea(
                rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self))
    }

    func showMore() {
        let visible = !editing && (hovering || menuOpen)
        guard visible == more.isHidden else { return }
        more.isHidden = !visible
        guard visible else { return }
        let animates =
            unsafe window?.isVisible == true
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        more.alphaValue = animates ? 0 : 1
        guard animates else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fade
            more.animator().alphaValue = 1
        }
    }

    func pressesMore(_ event: NSEvent) -> Bool {
        !more.isHidden && moreFrame.contains(convert(event.locationInWindow, from: nil))
    }

    func menuAnchor(for event: NSEvent) -> NSPoint {
        guard !pressesMore(event) else { return buttonAnchor }
        return unsafe window?.convertPoint(toScreen: event.locationInWindow) ?? .zero
    }

    func startHold(with event: NSEvent) {
        guard event.clickCount == 1, !opensOnSingleClick, onHold != nil else { return }
        holdOrigin = event.locationInWindow
        let grab = convert(event.locationInWindow, from: nil)
        holdDelay.start { [weak self] in
            guard let self, unsafe window != nil else { return }
            holdOrigin = nil
            onHold?(grab)
        }
    }

    func cancelHold(ifMovedBy event: NSEvent) {
        guard let origin = holdOrigin else { return }
        let moved = hypot(
            event.locationInWindow.x - origin.x, event.locationInWindow.y - origin.y)
        if moved > Self.holdSlop {
            holdOrigin = nil
            holdDelay.cancel()
        }
    }
}
