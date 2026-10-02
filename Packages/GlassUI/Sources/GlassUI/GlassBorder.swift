import AppKit

final class GlassBorder: NSView {
    private static let ringWidth: CGFloat = 0.5
    private static let rimWidth: CGFloat = 1
    private static let ringAlpha = (dark: 0.40, light: 0.08)
    private static let rimAlpha = (dark: 0.22, light: 0.55)
    private static let ringColor = NSColor(name: nil) { appearance in
        .black.withAlphaComponent(isDark(appearance) ? ringAlpha.dark : ringAlpha.light)
    }
    private static let rimColor = NSColor(name: nil) { appearance in
        .white.withAlphaComponent(isDark(appearance) ? rimAlpha.dark : rimAlpha.light)
    }

    let rim = CALayer()

    override var wantsUpdateLayer: Bool { true }

    init(radius: CGFloat) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = radius
        layer?.cornerCurve = .continuous
        layer?.borderWidth = Self.ringWidth
        rim.cornerRadius = radius - Self.ringWidth
        rim.cornerCurve = .continuous
        rim.borderWidth = Self.rimWidth
        layer?.addSublayer(rim)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        rim.frame = bounds.insetBy(dx: Self.ringWidth, dy: Self.ringWidth)
        CATransaction.commit()
    }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.borderColor = Self.ringColor.cgColor
            rim.borderColor = Self.rimColor.cgColor
        }
    }

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }
}
