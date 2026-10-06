import QuartzCore

final class LyricDots: CALayer {
    static let size: CGFloat = 10
    static let gap: CGFloat = 8
    static let count = 3
    static let rest: Float = 0.28
    static let width = CGFloat(count) * size + CGFloat(count - 1) * gap
    private static let key = "fill"
    private static let half: CGFloat = 0.5

    private(set) var dots: [CALayer] = []

    var colour: CGColor? {
        didSet { dots.forEach { $0.backgroundColor = colour } }
    }

    override init() {
        super.init()
        dots = (0..<Self.count).map { index in
            let dot = CALayer()
            dot.cornerRadius = Self.size * Self.half
            dot.frame = CGRect(
                x: CGFloat(index) * (Self.size + Self.gap), y: 0, width: Self.size,
                height: Self.size)
            dot.opacity = Self.rest
            addSublayer(dot)
            return dot
        }
        bounds = CGRect(x: 0, y: 0, width: Self.width, height: Self.size)
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    static func level(of index: Int, at progress: Double) -> Float {
        let filled = min(max(progress * Double(count) - Double(index), 0), 1)
        return rest + (1 - rest) * Float(filled)
    }

    func show(progress: Double, remaining: Double?, playing: Bool) {
        let left = 1 - progress
        let total = left > 0 ? remaining.map { $0 / left } : nil
        let now = convertTime(CACurrentMediaTime(), from: nil)
        CATransaction.quietly {
            for (index, dot) in dots.enumerated() {
                let start = Self.level(of: index, at: progress)
                dot.removeAnimation(forKey: Self.key)
                dot.opacity = start
                guard playing, let total, total > 0, start < 1 else { continue }
                dot.opacity = 1
                dot.add(
                    fill(index, from: start, at: progress, over: total, now: now), forKey: Self.key)
            }
        }
    }

    private func fill(
        _ index: Int, from start: Float, at progress: Double, over total: Double,
        now: CFTimeInterval
    ) -> CABasicAnimation {
        let opens = Double(index) / Double(Self.count)
        let closes = Double(index + 1) / Double(Self.count)
        let fill = CABasicAnimation(keyPath: "opacity")
        fill.fromValue = start
        fill.toValue = 1
        fill.beginTime = now + max(opens - progress, 0) * total
        fill.duration = (closes - max(opens, progress)) * total
        fill.fillMode = .backwards
        fill.timingFunction = CAMediaTimingFunction(name: .linear)
        return fill
    }
}
