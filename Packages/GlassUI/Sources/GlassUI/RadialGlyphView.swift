import AppKit

final class RadialGlyphView: NSView {
    private static let outlineAlpha = 0.65
    private static let areaAlpha = 0.85
    private static let colours = RadialGlyph.colours(outline: outlineAlpha, area: areaAlpha)

    var area = CGRect.zero {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize { RadialGlyph.size }

    override func draw(_: NSRect) {
        RadialGlyph.draw(area, at: .zero, colours: Self.colours)
    }
}
