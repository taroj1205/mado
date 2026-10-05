import AppKit

final class WidgetEqualizer: NSView {
    static let height: CGFloat = 11
    private static let barWidth: CGFloat = 2.5
    private static let barGap: CGFloat = 2
    private static let half: CGFloat = 0.5
    private static let low = 0.25
    private static let firstSeconds = 0.5
    private static let secondsStep = 0.11
    private static let restingBase = 0.4
    private static let restingStep = 0.3
    private static let restingCycle = 3
    private static let alpha = 0.9
    private static let barCount = 4
    private static let animation = "bounce"

    private let bars = (0..<barCount).map { _ in CALayer() }

    var isActive = false {
        didSet { animateBars() }
    }

    override var wantsUpdateLayer: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        let count = CGFloat(bars.count)
        return NSSize(
            width: count * Self.barWidth + (count - 1) * Self.barGap, height: Self.height)
    }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        for (index, bar) in bars.enumerated() {
            bar.anchorPoint = CGPoint(x: Self.half, y: 0)
            bar.bounds = CGRect(x: 0, y: 0, width: Self.barWidth, height: Self.height)
            bar.position = CGPoint(
                x: Self.barWidth * Self.half + CGFloat(index) * (Self.barWidth + Self.barGap), y: 0)
            bar.cornerRadius = Self.barWidth * Self.half
            layer?.addSublayer(bar)
        }
        animateBars()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        animateBars()
    }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let colour = NSColor.labelColor.withAlphaComponent(Self.alpha).cgColor
            bars.forEach { $0.backgroundColor = colour }
        }
    }

    private func animateBars() {
        let moves = isActive && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        for (index, bar) in bars.enumerated() {
            bar.removeAnimation(forKey: Self.animation)
            let resting = Self.restingBase + Self.restingStep * Double(index % Self.restingCycle)
            bar.transform = CATransform3DMakeScale(1, resting, 1)
            guard moves else { continue }
            let bounce = CABasicAnimation(keyPath: "transform.scale.y")
            bounce.fromValue = Self.low
            bounce.toValue = 1
            bounce.duration = Self.firstSeconds + Self.secondsStep * Double(index)
            bounce.autoreverses = true
            bounce.repeatCount = .infinity
            bounce.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            bar.add(bounce, forKey: Self.animation)
        }
    }
}
