import AppKit

final class WidgetFloatFrame: NSView {
    static let margin = WidgetTile.badgeOverhang

    private let glass: GlassView
    private let badge: NSView

    init(glass: GlassView, badge: NSView) {
        self.glass = glass
        self.badge = badge
        super.init(frame: .zero)
        badge.removeFromSuperview()
        badge.translatesAutoresizingMaskIntoConstraints = true
        addSubview(glass)
        addSubview(badge)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        glass.frame = bounds.insetBy(dx: Self.margin, dy: Self.margin)
        let size = WidgetTile.badgeSize
        badge.frame = NSRect(
            x: glass.frame.minX - Self.margin, y: glass.frame.maxY + Self.margin - size,
            width: size, height: size)
    }
}
