import AppKit

final class LyricLine: NSView {
    private static let size: CGFloat = 12.5
    private static let riseDistance: CGFloat = 6
    private static let riseSeconds = 0.45

    private let base = NSTextField(labelWithString: "")
    private let fill = NSTextField(labelWithString: "")
    private let wipe = WipeLines()
    private let lines: Int
    private var text = ""

    override var intrinsicContentSize: NSSize {
        base.intrinsicContentSize
    }

    private var textWidth: CGFloat {
        min(base.attributedStringValue.size().width, bounds.width)
    }

    private var font: NSFont {
        base.font ?? .systemFont(ofSize: Self.size)
    }

    private var wipeRects: [CGRect] {
        guard lines > 1 else {
            return [CGRect(x: 0, y: 0, width: textWidth, height: bounds.height)]
        }
        let wrap = LyricsWrap(text, font: font, width: bounds.width, lines: lines)
        let flipped = fill.layer?.isGeometryFlipped ?? false
        return wrap.rects.map { line in
            CGRect(
                x: line.minX, y: flipped ? line.minY : bounds.height - line.maxY,
                width: ceil(line.width) + 1, height: line.height)
        }
    }

    convenience init() {
        self.init(size: Self.size, weight: .medium, lines: 1)
    }

    convenience init(size: CGFloat, weight: NSFont.Weight) {
        self.init(size: size, weight: weight, lines: 1)
    }

    init(size: CGFloat, weight: NSFont.Weight, lines: Int) {
        self.lines = lines
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        base.textColor = .secondaryLabelColor
        fill.textColor = .labelColor
        for label in [base, fill] {
            label.font = .systemFont(ofSize: size, weight: weight)
            label.maximumNumberOfLines = lines
            if lines > 1 {
                label.cell?.wraps = true
                label.cell?.truncatesLastVisibleLine = true
            } else {
                label.lineBreakMode = .byTruncatingTail
            }
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
        CATransaction.quietly {
            wipe.frame = bounds
            wipe.fit(wipeRects)
        }
    }

    func height(for width: CGFloat) -> CGFloat {
        let single = base.intrinsicContentSize.height
        guard lines > 1 else { return single }
        return max(single, LyricsWrap(text, font: font, width: width, lines: lines).height)
    }

    func show(_ lyric: WidgetGrid.Lyric, playing: Bool) {
        let changed = lyric.text != text
        if changed {
            text = lyric.text
            set(lyric.text)
            wipe.forget()
            invalidateIntrinsicContentSize()
            layoutSubtreeIfNeeded()
            CATransaction.quietly { wipe.fit(wipeRects) }
            rise()
        }
        wipe.run(
            from: lyric.progress, remaining: lyric.remaining, playing: playing, restart: changed)
    }

    private func set(_ text: String) {
        guard lines > 1 else {
            base.stringValue = text
            fill.stringValue = text
            return
        }
        base.attributedStringValue = LyricsWrap.string(
            text, font: font, color: .secondaryLabelColor)
        fill.attributedStringValue = LyricsWrap.string(text, font: font, color: .labelColor)
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
