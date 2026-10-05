import AppKit

final class LyricLine: NSView {
    private static let size: CGFloat = 12.5
    private static let riseDistance: CGFloat = 6
    private static let riseSeconds = 0.45

    private let base = NSTextField(labelWithString: "")
    private let fill = NSTextField(labelWithString: "")
    private let wipe = WipeMask()
    private var text = ""

    override var intrinsicContentSize: NSSize {
        base.intrinsicContentSize
    }

    private var textWidth: CGFloat {
        min(base.attributedStringValue.size().width, bounds.width)
    }

    convenience init() {
        self.init(size: Self.size, weight: .medium)
    }

    init(size: CGFloat, weight: NSFont.Weight) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        base.textColor = .secondaryLabelColor
        fill.textColor = .labelColor
        for label in [base, fill] {
            label.font = .systemFont(ofSize: size, weight: weight)
            label.lineBreakMode = .byTruncatingTail
            label.translatesAutoresizingMaskIntoConstraints = false
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: leadingAnchor),
                label.trailingAnchor.constraint(equalTo: trailingAnchor),
                label.topAnchor.constraint(equalTo: topAnchor),
                label.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        }
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        fill.wantsLayer = true
        fill.layer?.mask = wipe
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        CATransaction.quietly { wipe.fit(width: textWidth, height: bounds.height) }
    }

    func show(_ lyric: WidgetGrid.Lyric, playing: Bool) {
        let changed = lyric.text != text
        if changed {
            text = lyric.text
            base.stringValue = lyric.text
            fill.stringValue = lyric.text
            invalidateIntrinsicContentSize()
            layoutSubtreeIfNeeded()
            rise()
        }
        wipe.run(
            from: lyric.progress, remaining: lyric.remaining, playing: playing, restart: changed)
    }

    private func rise() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, let layer else { return }
        let lift = CABasicAnimation(keyPath: "transform.translation.y")
        lift.fromValue = -Self.riseDistance
        lift.toValue = 0
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        let group = CAAnimationGroup()
        group.animations = [lift, fade]
        group.duration = Self.riseSeconds
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(group, forKey: "rise")
    }
}
