import AppKit

final class Spinner: NSView {
    private static let size: CGFloat = 16
    private static let lineWidth: CGFloat = 2
    private static let inset: CGFloat = 1
    private static let trackAlpha: CGFloat = 0.25
    private static let arc: CGFloat = 0.25
    private static let halfTurnSeconds: CFTimeInterval = 0.4
    private static let spin = "spin"

    private let track = CAShapeLayer()
    private let head = CAShapeLayer()

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.size, height: Self.size)
    }

    override var wantsUpdateLayer: Bool {
        true
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        let bounds = CGRect(x: 0, y: 0, width: Self.size, height: Self.size)
        let ring = NSBezierPath(
            ovalIn: bounds.insetBy(dx: Self.inset, dy: Self.inset)
        ).cgPath
        for shape in [track, head] {
            shape.frame = bounds
            shape.path = ring
            shape.fillColor = nil
            shape.lineWidth = Self.lineWidth
            layer?.addSublayer(shape)
        }
        head.strokeEnd = Self.arc
        head.lineCap = .round
        let turn = CABasicAnimation(keyPath: "transform.rotation.z")
        turn.fromValue = 0
        turn.toValue = -CGFloat.pi
        turn.isCumulative = true
        turn.duration = Self.halfTurnSeconds
        turn.repeatCount = .infinity
        turn.isRemovedOnCompletion = false
        head.add(turn, forKey: Self.spin)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            track.strokeColor = NSColor.labelColor.withAlphaComponent(Self.trackAlpha).cgColor
            head.strokeColor = NSColor.labelColor.cgColor
        }
    }
}
