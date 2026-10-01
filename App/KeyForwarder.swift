#if DEBUG
    import AppKit

    @MainActor
    func forwardKeys(to panel: NSPanel) {
        _ = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak panel] event in
            guard let panel, panel.isVisible, event.window == nil else { return event }
            if !panel.performKeyEquivalent(with: event) {
                panel.firstResponder?.keyDown(with: event)
            }
            return nil
        }
    }
#endif
