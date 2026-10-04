import AppKit

final class WidgetDropFrame: NSView {
    private static let edgeWidth: CGFloat = 1.5
    private static let edgeAlpha: CGFloat = 0.7
    private static let fillAlpha: CGFloat = 0.10
    private static let labelLift: CGFloat = 0.45
    private static let fontSize: CGFloat = 12.5
    private static let symbolSize: CGFloat = 12
    private static let gap: CGFloat = 6
    private static let tint = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor.controlAccentColor.blended(withFraction: labelLift, of: .white)
                ?? .controlAccentColor
            : .controlAccentColor
    }

    let label = NSTextField(labelWithString: "Drop to add")

    override init(frame: NSRect) {
        super.init(frame: frame)
        let outline = DashedOutline(
            colour: .controlAccentColor.withAlphaComponent(Self.edgeAlpha), width: Self.edgeWidth,
            fill: .controlAccentColor.withAlphaComponent(Self.fillAlpha))
        outline.frame = bounds
        outline.autoresizingMask = [.width, .height]
        addSubview(outline)
        let plus = NSImageView(
            image: NSImage(systemSymbolName: "plus", accessibilityDescription: nil) ?? NSImage())
        plus.symbolConfiguration = .init(pointSize: Self.symbolSize, weight: .semibold)
        plus.contentTintColor = Self.tint
        label.font = .systemFont(ofSize: Self.fontSize, weight: .semibold)
        label.textColor = Self.tint
        let stack = NSStackView(views: [plus, label])
        stack.spacing = Self.gap
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }
}
