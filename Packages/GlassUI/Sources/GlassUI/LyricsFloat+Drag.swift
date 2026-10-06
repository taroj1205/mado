import AppKit

extension LyricsFloat {
    func drag(_ phase: LyricsCard.Drag) {
        switch phase {
        case .began: beginDrag()
        case .moved: moveDrag()
        case .ended: endDrag()
        }
    }

    func beginDrag() {
        guard isShown, case .corner(let corner) = place else { return }
        let point = pointer()
        drag = Drag(
            grab: NSSize(width: point.x - panel.frame.minX, height: point.y - panel.frame.minY),
            corner: corner, screen: screen)
        showSlots(at: point)
    }

    func moveDrag() {
        guard let grab = drag?.grab else { return }
        drag?.moved = true
        let point = pointer()
        panel.setFrameOrigin(NSPoint(x: point.x - grab.width, y: point.y - grab.height))
        showSlots(at: point)
    }

    func endDrag() {
        guard let moved = drag?.moved else { return }
        drag = nil
        hideSlots()
        target = nil
        guard moved, let landing = screen(at: pointer()) else {
            settle(animated: true)
            return
        }
        let centre = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        let corner = LyricsGeometry.nearest(to: centre, in: landing.visibleFrame)
        place = .corner(corner)
        screen = landing
        settle(animated: true)
        onMove?(corner, landing)
    }

    func hideSlots() {
        slots.values.forEach { $0.orderOut(nil) }
    }

    private func screen(at point: NSPoint) -> NSScreen? {
        let all = screens()
        return LyricsGeometry.screen(at: point, in: all.map(\.frame)).map { all[$0] }
    }

    private func showSlots(at point: NSPoint) {
        guard let drag, let under = screen(at: point) else { return }
        let frames = LyricsGeometry.slots(
            size: panel.frame.size, in: under.visibleFrame,
            except: under == drag.screen ? drag.corner : nil)
        for corner in LyricsCorner.allCases {
            guard let frame = frames[corner] else {
                slots[corner]?.orderOut(nil)
                continue
            }
            let slot = slots[corner] ?? LyricsFloatSlot.panel(for: corner, radius: Self.radius)
            slots[corner] = slot
            slot.sharingType = panel.sharingType
            slot.setFrame(frame, display: true)
            slot.order(.below, relativeTo: panel.windowNumber)
        }
    }
}
