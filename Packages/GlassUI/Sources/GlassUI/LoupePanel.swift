import AppKit
import Carbon.HIToolbox

final class LoupePanel: NSPanel {
    private static let keys: [Int: ColourLoupe.Input] = [
        kVK_LeftArrow: .nudged(across: -1, down: 0), kVK_RightArrow: .nudged(across: 1, down: 0),
        kVK_UpArrow: .nudged(across: 0, down: -1), kVK_DownArrow: .nudged(across: 0, down: 1),
        kVK_ANSI_H: .nudged(across: -1, down: 0), kVK_ANSI_L: .nudged(across: 1, down: 0),
        kVK_ANSI_K: .nudged(across: 0, down: -1), kVK_ANSI_J: .nudged(across: 0, down: 1),
        kVK_Return: .picked, kVK_ANSI_KeypadEnter: .picked, kVK_Escape: .cancelled,
    ]

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

    static func input(for event: NSEvent, in window: NSWindow) -> ColourLoupe.Input? {
        switch event.type {
        case .mouseMoved, .leftMouseDragged:
            .moved((event.window ?? window).convertPoint(toScreen: event.locationInWindow))

        case .leftMouseUp: .picked
        case .keyDown: keys[Int(event.keyCode)]
        default: nil
        }
    }

    override func sendEvent(_ event: NSEvent) {
        if let input = Self.input(for: event, in: self) {
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
