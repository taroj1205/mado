import AppKit

final class LyricsPaneProgress: NSView {
    struct Anchor {
        let position: TimeInterval
        let since: TimeInterval
        let playing: Bool
    }

    static let barHeight: CGFloat = 4
    private static let timeGap: CGFloat = 6
    private static let timeSize: CGFloat = 11
    private static let trackAlpha = (dark: 0.14, light: 0.10)
    private static let track = WidgetTile.tone(.white, .black, trackAlpha)
    private static let jump: TimeInterval = 1.5
    private static let half: CGFloat = 0.5
    private static let pattern = Duration.TimeFormatStyle(pattern: .minuteSecond)

    let elapsed = NSTextField(labelWithString: "")
    let total = NSTextField(labelWithString: "")
    var uptime = { ProcessInfo.processInfo.systemUptime }
    private(set) var anchor: Anchor?
    private var duration: TimeInterval?
    private let bar = CALayer()
    private let fill = CALayer()
    private let wipe = WipeMask()
    private var ticking: Task<Void, Never>?

    override var isFlipped: Bool {
        true
    }

    override var wantsUpdateLayer: Bool {
        true
    }

    private var position: TimeInterval? {
        guard let anchor else { return nil }
        let moved = anchor.position + (anchor.playing ? uptime() - anchor.since : 0)
        return duration.map { min(moved, $0) } ?? moved
    }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        bar.cornerRadius = Self.barHeight * Self.half
        bar.masksToBounds = true
        fill.mask = wipe
        bar.addSublayer(fill)
        layer?.addSublayer(bar)
        for label in [elapsed, total] {
            label.font = .monospacedDigitSystemFont(ofSize: Self.timeSize, weight: .regular)
            label.textColor = .secondaryLabelColor
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
        }
        NSLayoutConstraint.activate([
            elapsed.leadingAnchor.constraint(equalTo: leadingAnchor),
            elapsed.topAnchor.constraint(
                equalTo: topAnchor, constant: Self.barHeight + Self.timeGap),
            elapsed.bottomAnchor.constraint(equalTo: bottomAnchor),
            total.trailingAnchor.constraint(equalTo: trailingAnchor),
            total.firstBaselineAnchor.constraint(equalTo: elapsed.firstBaselineAnchor),
        ])
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    static func clock(_ seconds: TimeInterval) -> String {
        Duration.seconds(Int(max(seconds, 0))).formatted(pattern)
    }

    override func layout() {
        super.layout()
        CATransaction.quietly {
            bar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: Self.barHeight)
            fill.frame = bar.bounds
            wipe.fit(width: bounds.width, height: Self.barHeight)
        }
    }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            bar.backgroundColor = Self.track.cgColor
            fill.backgroundColor = NSColor.labelColor.cgColor
        }
    }

    func show(position next: TimeInterval?, duration: TimeInterval?, playing: Bool) {
        let jumped = position.flatMap { old in next.map { abs(old - $0) > Self.jump } } ?? true
        self.duration = duration
        anchor = next.map { Anchor(position: $0, since: uptime(), playing: playing) }
        total.stringValue = duration.map(Self.clock) ?? ""
        showElapsed()
        var fraction = 0.0
        var remaining: TimeInterval?
        if let next, let duration, duration > 0 {
            fraction = min(next / duration, 1)
            remaining = max(duration - next, 0)
        }
        wipe.run(from: fraction, remaining: remaining, playing: playing, restart: jumped)
        ticking?.cancel()
        ticking = playing && next != nil ? tick() : nil
    }

    private func showElapsed() {
        elapsed.stringValue = position.map(Self.clock) ?? ""
    }

    private func tick() -> Task<Void, Never> {
        Task { [weak self] in
            while !Task.isCancelled {
                let shown = self?.position ?? 0
                try? await Task.sleep(for: .seconds(1 - shown.truncatingRemainder(dividingBy: 1)))
                guard !Task.isCancelled, let self, unsafe window?.isVisible == true else { return }
                showElapsed()
            }
        }
    }
}
