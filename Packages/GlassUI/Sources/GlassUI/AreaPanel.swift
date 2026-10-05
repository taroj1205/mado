import AppKit
import Carbon.HIToolbox

final class AreaPanel: NSPanel {
    let area: AreaView
    var takesKeys = false
    var onSelect: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { takesKeys }

    init(frame: CGRect) {
        area = AreaView(frame: CGRect(origin: .zero, size: frame.size))
        super.init(
            contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
            defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = area
        area.onSelect = { [weak self] rect in
            guard let self else { return }
            onSelect?(convertToScreen(rect))
        }
    }

    override func sendEvent(_ event: NSEvent) {
        guard event.type == .keyDown else {
            super.sendEvent(event)
            return
        }
        if Int(event.keyCode) == kVK_Escape { onCancel?() }
    }

    override func resignKey() {
        super.resignKey()
        if takesKeys { onCancel?() }
    }
}
