import AppKit

final class SettingsSidebarRow: NSTableRowView {
    private static let inset: CGFloat = 10
    private static let radius: CGFloat = 8
    private static let alpha: CGFloat = 0.1

    override var interiorBackgroundStyle: NSView.BackgroundStyle {
        .normal
    }

    override func drawSelection(in _: NSRect) {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            NSColor.labelColor.withAlphaComponent(Self.alpha).setFill()
            NSBezierPath(
                roundedRect: bounds.insetBy(dx: Self.inset, dy: 0),
                xRadius: Self.radius, yRadius: Self.radius
            )
            .fill()
        }
    }
}
