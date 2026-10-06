import AppKit

@MainActor
enum LyricsFloatSlot {
    private static let edge: CGFloat = 1.5
    private static let labelSize: CGFloat = 11
    private static let dashAlpha: CGFloat = 0.22
    private static let fillAlpha: CGFloat = 0.025
    private static let dash = tone(dashAlpha)
    private static let fill = tone(fillAlpha)

    static func panel(for corner: LyricsCorner, radius: CGFloat) -> OverlayPanel {
        let panel = OverlayPanel()
        panel.animationBehavior = .none
        let outline = DashedOutline(colour: dash, width: edge, fill: fill, radius: radius)
        let label = NSTextField(labelWithString: corner.name)
        label.font = .systemFont(ofSize: labelSize)
        label.textColor = .tertiaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        outline.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: outline.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: outline.centerYAnchor),
        ])
        outline.setAccessibilityElement(false)
        panel.contentView = outline
        return panel
    }

    private static func tone(_ alpha: CGFloat) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? .white.withAlphaComponent(alpha) : .black.withAlphaComponent(alpha)
        }
    }
}
