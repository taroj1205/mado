import AppCore
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
        fit(CGRect(x: 0, y: 0, width: width, height: height))
    }

    func fit(_ rect: CGRect) {
        bounds = CGRect(origin: .zero, size: rect.size)
        position = CGPoint(x: rect.minX, y: rect.midY)
    }

    func run(from start: Double, remaining: Double?, playing: Bool, restart: Bool) {
        run(
            WipeSweep(start: start, remaining: remaining, ahead: []), playing: playing,
            restart: restart)
    }

    func run(_ sweep: WipeSweep, playing: Bool, restart: Bool) {
        run(sweep, delay: 0, playing: playing, restart: restart)
    }

    func run(_ sweep: WipeSweep, delay: Double, playing: Bool, restart: Bool) {
        let from = max(sweep.start, Self.smallest)
        let runs = playing && (sweep.remaining ?? 0) > 0
        guard
            restart || state?.playing != playing || state?.runs != runs
                || abs(progress - sweep.start) > Self.drift
        else { return }
        state = (playing, runs)
        CATransaction.quietly {
            removeAnimation(forKey: Self.key)
            transform = CATransform3DMakeScale(runs ? 1 : from, 1, 1)
        }
        guard runs, let remaining = sweep.remaining else { return }
        let animation = animation(from: from, over: remaining, through: sweep.ahead)
        if delay > 0 {
            animation.beginTime = convertTime(CACurrentMediaTime(), from: nil) + delay
            animation.fillMode = .backwards
        }
        add(animation, forKey: Self.key)
    }

    private func animation(
        from start: Double, over remaining: Double, through ahead: [Lyrics.Step]
    ) -> CAPropertyAnimation {
        guard let last = ahead.last?.seconds, last > 0 else {
            let sweep = CABasicAnimation(keyPath: Self.scale)
            sweep.fromValue = start
            sweep.toValue = 1
            sweep.duration = remaining
            sweep.timingFunction = CAMediaTimingFunction(name: .linear)
            return sweep
        }
        let sweep = CAKeyframeAnimation(keyPath: Self.scale)
        let reaches: [Double] = [start] + ahead.map { step in max(step.reach, start) }
        let times: [Double] = [0] + ahead.map { step in min(step.seconds / last, 1) }
        sweep.values = reaches
        sweep.setValue(times, forKey: "keyTimes")
        sweep.calculationMode = .linear
        sweep.duration = remaining
        return sweep
    }
}
