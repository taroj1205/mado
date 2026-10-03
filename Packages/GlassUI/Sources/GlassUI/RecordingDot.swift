import AppKit

final class RecordingDot: NSView {
    private static let size: CGFloat = 8
    private static let ring: CGFloat = 4
    private static let ringAlpha: CGFloat = 0.25
    private static let half: CGFloat = 0.5

    private let halo = CALayer()

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.size, height: Self.size)
    }

    override var wantsUpdateLayer: Bool { true }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = Self.size * Self.half
        layer?.masksToBounds = false
        let outer = Self.size + Self.ring + Self.ring
        halo.frame = CGRect(x: -Self.ring, y: -Self.ring, width: outer, height: outer)
        halo.cornerRadius = outer * Self.half
        layer?.insertSublayer(halo, at: 0)
        setContentHuggingPriority(.required, for: .horizontal)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.systemRed.cgColor
            halo.backgroundColor = NSColor.systemRed.withAlphaComponent(Self.ringAlpha).cgColor
        }
    }
}
