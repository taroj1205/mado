public import AppKit

public final class GlassPanel: NSPanel {
    public enum Kind: Sendable {
        case panel
        case hud
    }

    private let kind: Kind
    public let glass: GlassView
    public var onKeyDown: ((NSEvent) -> Bool)?

    override public var canBecomeKey: Bool { kind == .panel }

    public init(kind: Kind, contentRect: NSRect, shape: GlassView.Shape) {
        self.kind = kind
        glass = GlassView(shape: shape)
        super.init(
            contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isFloatingPanel = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = glass
        if kind == .hud {
            ignoresMouseEvents = true
            level = .statusBar
        }
    }

    override public func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, onKeyDown?(event) == true { return }
        super.sendEvent(event)
    }
}
