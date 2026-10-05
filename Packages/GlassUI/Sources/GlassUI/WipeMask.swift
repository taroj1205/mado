import AppKit

final class WipeMask: CALayer {
    private static let smallest = 0.001
    private static let drift = 0.08
    private static let key = "sweep"
    private static let scale = "transform.scale.x"
    private static let half: CGFloat = 0.5

    private var state: (playing: Bool, runs: Bool)?

    var progress: Double {
        ((presentation() ?? self).value(forKeyPath: Self.scale) as? Double) ?? 0
    }

    override init() {
        super.init()
        anchorPoint = CGPoint(x: 0, y: Self.half)
        backgroundColor = NSColor.black.cgColor
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func fit(width: CGFloat, height: CGFloat) {
        bounds = CGRect(x: 0, y: 0, width: width, height: height)
        position = CGPoint(x: 0, y: height * Self.half)
    }

    func run(from start: Double, remaining: Double?, playing: Bool, restart: Bool) {
        let from = max(start, Self.smallest)
        let runs = playing && (remaining ?? 0) > 0
        guard
            restart || state?.playing != playing || state?.runs != runs
                || abs(progress - start) > Self.drift
        else { return }
        state = (playing, runs)
        CATransaction.quietly {
            removeAnimation(forKey: Self.key)
            transform = CATransform3DMakeScale(runs ? 1 : from, 1, 1)
        }
        guard runs, let remaining else { return }
        let sweep = CABasicAnimation(keyPath: Self.scale)
        sweep.fromValue = from
        sweep.toValue = 1
        sweep.duration = remaining
        sweep.timingFunction = CAMediaTimingFunction(name: .linear)
        add(sweep, forKey: Self.key)
    }
}
