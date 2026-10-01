public import AppKit

public final class GlassPanel: NSPanel {
    public enum Kind: Sendable {
        case panel
        case hud
    }

    private let kind: Kind
    public let glass: GlassView

    override public var canBecomeKey: Bool { kind == .panel }

    public init(kind: Kind, contentRect: NSRect, shape: GlassView.Shape) {
        self.kind = kind
        glass = GlassView(shape: shape)
        super.init(
            contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: true)
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
}
