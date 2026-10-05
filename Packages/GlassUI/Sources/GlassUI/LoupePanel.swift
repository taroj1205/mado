import AppKit
import Carbon.HIToolbox

final class LoupePanel: NSPanel {
    var keys = LoupeKeys()
    var takesKeys = false
    var onInput: ((ColourLoupe.Input) -> Void)?

    override var canBecomeKey: Bool { takesKeys }

    init(frame: CGRect) {
        super.init(
            contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
            defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = NSView(frame: CGRect(origin: .zero, size: frame.size))
        view.addTrackingArea(
            NSTrackingArea(
                rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: view))
        contentView = view
    }

    func input(for event: NSEvent) -> ColourLoupe.Input? {
        switch event.type {
        case .mouseMoved, .leftMouseDragged:
            .moved((event.window ?? self).convertPoint(toScreen: event.locationInWindow))

        case .leftMouseUp: .picked
        case .keyDown: keys.input(for: Int(event.keyCode))
        default: nil
        }
    }

    override func sendEvent(_ event: NSEvent) {
        if let input = input(for: event) {
            onInput?(input)
        } else if event.type != .keyDown {
            super.sendEvent(event)
        }
    }

    override func resignKey() {
        super.resignKey()
        if takesKeys { onInput?(.cancelled) }
    }
}
