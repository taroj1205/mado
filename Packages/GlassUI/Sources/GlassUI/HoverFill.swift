public import AppKit

public final class HoverFill: NSView {
    private static let alpha = (dark: 0.12, light: 0.08)
    private static let tint = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? .white.withAlphaComponent(alpha.dark)
            : .black.withAlphaComponent(alpha.light)
    }

    private(set) var isHovered = false {
        didSet { if isHovered != oldValue { needsDisplay = true } }
    }

    public var radius: CGFloat {
        didSet { layer?.cornerRadius = radius }
    }

    override public var wantsUpdateLayer: Bool { true }

    public init(radius: CGFloat) {
        self.radius = radius
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = radius
        layer?.cornerCurve = .continuous
        addTrackingArea(
            NSTrackingArea(
                rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    @discardableResult
    public static func install(
        in view: NSView, radius: CGFloat, below sibling: NSView? = nil
    ) -> HoverFill {
        let fill = HoverFill(radius: radius)
        fill.frame = view.bounds
        fill.autoresizingMask = [.width, .height]
        view.addSubview(fill, positioned: .below, relativeTo: sibling)
        return fill
    }

    override public func resize(withOldSuperviewSize _: NSSize) {
        if let superview = unsafe superview { frame = superview.bounds }
    }

    override public func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    override public func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = isHovered ? Self.tint.cgColor : nil
        }
    }

    override public func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        isHovered = false
    }

    override public func viewDidHide() {
        super.viewDidHide()
        isHovered = false
    }

    override public func mouseEntered(with _: NSEvent) {
        isHovered = NSEvent.pressedMouseButtons == 0
    }

    override public func mouseExited(with _: NSEvent) {
        isHovered = false
    }
}
