import AppKit

final class SettingsSidebarRow: NSTableRowView {
    private static let inset: CGFloat = 10
    private static let radius: CGFloat = 8
    private static let alpha: CGFloat = 0.1

    private let accent: Bool

    override var interiorBackgroundStyle: NSView.BackgroundStyle {
        accent && isSelected ? .emphasized : .normal
    }

    init(accent: Bool) {
        self.accent = accent
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func drawSelection(in _: NSRect) {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let quiet = NSColor.labelColor.withAlphaComponent(Self.alpha)
            (accent ? .controlAccentColor : quiet).setFill()
            NSBezierPath(
                roundedRect: bounds.insetBy(dx: Self.inset, dy: 0),
                xRadius: Self.radius, yRadius: Self.radius
            )
            .fill()
        }
    }
}
