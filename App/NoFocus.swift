#if DEBUG
    import AppKit
    import GlassUI

    @MainActor
    enum NoFocus {
        static let isEnabled = UserDefaults.standard.bool(forKey: "MadoNoFocus")

        static func show(_ panel: NSPanel) {
            if isEnabled {
                panel.orderFrontRegardless()
            } else {
                panel.makeKeyAndOrderFront(nil)
            }
        }

        static func forwardKeys(to panel: GlassPanel) {
            _ = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak panel] event in
                guard let panel, panel.isVisible, event.window == nil else { return event }
                if panel.onKeyDown?(event) != true, !panel.performKeyEquivalent(with: event) {
                    panel.firstResponder?.keyDown(with: event)
                }
                return nil
            }
        }
    }
#endif
