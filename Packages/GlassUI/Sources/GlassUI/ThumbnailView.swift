import AppKit

final class ThumbnailView: NSView {
    private static let radius: CGFloat = 6
    private static let edgeWidth: CGFloat = 0.5
    private static let edgeAlpha = (dark: 0.24, light: 0.18)
    private static let edge = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? .white.withAlphaComponent(edgeAlpha.dark)
            : .black.withAlphaComponent(edgeAlpha.light)
    }

    var image: CGImage? {
        didSet { needsDisplay = true }
    }

    override var wantsUpdateLayer: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.contentsGravity = .resizeAspectFill
        layer?.masksToBounds = true
        layer?.cornerRadius = Self.radius
        layer?.cornerCurve = .continuous
        layer?.borderWidth = Self.edgeWidth
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func updateLayer() {
        layer?.contents = image
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.borderColor = Self.edge.cgColor
        }
    }
}
