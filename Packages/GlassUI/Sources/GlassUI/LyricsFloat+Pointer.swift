import AppKit

extension LyricsFloat {
    var grows: Bool {
        guard look == .line else { return false }
        return switch place {
        case .island, .corner: true
        case .menuBar, .desktop, nil: false
        }
    }

    func tick() {
        guard isShown, let place, place != .desktop else { return }
        let point = pointer()
        hover(at: point)
        let passes = drag == nil && !takesClick(at: point)
        if panel.ignoresMouseEvents != passes {
            panel.ignoresMouseEvents = passes
        }
        guard case .menuBar(let anchor) = place, buttons() != 0,
            !panel.frame.contains(point), !anchor.contains(point)
        else { return }
        hide(animated: true)
        onDismiss?()
    }

    func takesClick(at point: NSPoint) -> Bool {
        guard panel.frame.contains(point) else { return false }
        if case .corner = place { return true }
        let local = panel.glass.container.convert(panel.convertPoint(fromScreen: point), from: nil)
        return card.hitTest(local) is LyricsCardButton
    }

    private func hover(at point: NSPoint) {
        guard grows, drag == nil else { return }
        guard panel.frame.contains(point) else {
            hoverSince = nil
            if grown {
                grown = false
                settle(animated: true)
            }
            return
        }
        let since = hoverSince ?? now()
        hoverSince = since
        guard !grown, now() - since >= .milliseconds(Self.hoverMilliseconds) else { return }
        grown = true
        settle(animated: true)
    }
}
