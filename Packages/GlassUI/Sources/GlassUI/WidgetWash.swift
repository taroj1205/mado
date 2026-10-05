import AppKit

final class WidgetWash: NSView {
    private static let inset: CGFloat = 1
    private static let fromAlpha = (dark: 0.5, light: 0.34)
    private static let toAlpha = (dark: 0.05, light: 0.04)
    private static let middle: CGFloat = 0.5
    private static let slope: CGFloat = 0.35
    private static let lightening: CGFloat = 0.3

    private let gradient = CAGradientLayer()

    var tint: NSColor? {
        didSet {
            guard tint != oldValue else { return }
            isHidden = tint == nil
            needsDisplay = true
        }
    }

    override var wantsUpdateLayer: Bool {
        true
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        gradient.startPoint = CGPoint(x: 0, y: Self.middle + Self.slope)
        gradient.endPoint = CGPoint(x: 1, y: Self.middle - Self.slope)
        gradient.cornerRadius = WidgetTile.radius - Self.inset
        layer?.addSublayer(gradient)
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        CATransaction.quietly {
            gradient.frame = bounds.insetBy(dx: Self.inset, dy: Self.inset)
        }
    }

    override func updateLayer() {
        guard let tint else { return }
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let alphas =
                dark
                ? [Self.fromAlpha.dark, Self.toAlpha.dark]
                : [Self.fromAlpha.light, Self.toAlpha.light]
            let base = dark ? tint : tint.blended(withFraction: Self.lightening, of: .white) ?? tint
            gradient.colors = alphas.map { alpha in base.withAlphaComponent(alpha).cgColor }
        }
    }
}
