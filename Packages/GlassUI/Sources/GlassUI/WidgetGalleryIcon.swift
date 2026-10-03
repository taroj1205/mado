import AppKit

final class WidgetGalleryIcon: NSView {
    private static let side: CGFloat = 32
    private static let radius: CGFloat = 8.5
    private static let glyphSize: CGFloat = 15
    private static let lighten: CGFloat = 0.2
    private static let darken: CGFloat = 0.16
    private static let rim: CGFloat = 0.75
    private static let rimAlpha = (bottom: 0.04, top: 0.38)
    private static let sheenAlpha = 0.14
    private static let sheenDepth: CGFloat = 0.55
    private static let shadowAlpha: Float = 0.3
    private static let shadowBlur: CGFloat = 3
    private static let shadowDrop: CGFloat = -1
    private static let glyphShadowAlpha = 0.25
    private static let glyphShadowDrop: CGFloat = -0.5
    private static let glyphShadowBlur: CGFloat = 1
    private static let upward: CGFloat = 90

    private let colour: NSColor

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.side, height: Self.side)
    }

    init(symbol: String, colour: NSColor) {
        self.colour = colour
        super.init(frame: .zero)
        wantsLayer = true
        layer?.shadowColor = .black
        layer?.shadowOpacity = Self.shadowAlpha
        layer?.shadowRadius = Self.shadowBlur
        layer?.shadowOffset = CGSize(width: 0, height: Self.shadowDrop)
        let glyph = NSImageView()
        glyph.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        glyph.symbolConfiguration = .init(pointSize: Self.glyphSize, weight: .semibold)
        glyph.contentTintColor = .white
        let lift = NSShadow()
        lift.shadowColor = .black.withAlphaComponent(Self.glyphShadowAlpha)
        lift.shadowOffset = NSSize(width: 0, height: Self.glyphShadowDrop)
        lift.shadowBlurRadius = Self.glyphShadowBlur
        glyph.shadow = lift
        glyph.translatesAutoresizingMaskIntoConstraints = false
        addSubview(glyph)
        NSLayoutConstraint.activate([
            glyph.centerXAnchor.constraint(equalTo: centerXAnchor),
            glyph.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        setContentHuggingPriority(.required, for: .horizontal)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        layer?.shadowPath =
            NSBezierPath(roundedRect: bounds, xRadius: Self.radius, yRadius: Self.radius).cgPath
    }

    override func draw(_: NSRect) {
        let shape = NSBezierPath(roundedRect: bounds, xRadius: Self.radius, yRadius: Self.radius)
        let top = colour.blended(withFraction: Self.lighten, of: .white) ?? colour
        let bottom = colour.blended(withFraction: Self.darken, of: .black) ?? colour
        NSGradient(starting: bottom, ending: top)?.draw(in: shape, angle: Self.upward)

        var sheen = bounds
        sheen.size.height *= Self.sheenDepth
        sheen.origin.y = bounds.maxY - sheen.height
        NSGraphicsContext.saveGraphicsState()
        shape.addClip()
        NSGradient(
            starting: .white.withAlphaComponent(0),
            ending: .white.withAlphaComponent(Self.sheenAlpha))?
            .draw(in: sheen, angle: Self.upward)
        NSGraphicsContext.restoreGraphicsState()

        let ring = NSBezierPath(roundedRect: bounds, xRadius: Self.radius, yRadius: Self.radius)
        ring.append(
            NSBezierPath(
                roundedRect: bounds.insetBy(dx: Self.rim, dy: Self.rim),
                xRadius: Self.radius - Self.rim, yRadius: Self.radius - Self.rim))
        ring.windingRule = .evenOdd
        NSGradient(
            starting: .white.withAlphaComponent(Self.rimAlpha.bottom),
            ending: .white.withAlphaComponent(Self.rimAlpha.top))?
            .draw(in: ring, angle: Self.upward)
    }
}
