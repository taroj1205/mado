import AppKit

final class LyricsDesktop: NSView {
    private static let restSize: CGFloat = 15
    private static let lineSize: CGFloat = 26
    private static let gap: CGFloat = 6

    let previous = LyricsDesktop.rest()
    let line = LyricLine(size: lineSize, weight: .semibold)
    let next = LyricsDesktop.rest()
    var reducesMotion = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    private let stack: NSStackView
    private var text: LyricsFloatText?

    init() {
        stack = NSStackView(views: [previous, line, next])
        super.init(frame: .zero)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.gap
        stack.translatesAutoresizingMaskIntoConstraints = false
        line.wantsLayer = true
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Lyrics")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func rest() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: restSize)
        label.textColor = .tertiaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func show(_ verse: WidgetGrid.Verse) {
        let shown = LyricsFloatText(verse)
        if text?.line != shown.line, text != nil, reducesMotion() {
            LyricsCard.crossFade(line.layer, seconds: LyricsCard.swapSeconds)
        }
        text = shown
        previous.stringValue = shown.previous ?? ""
        next.stringValue = shown.next ?? ""
        line.show(shown.lyric(of: verse), playing: verse.isPlaying)
        setAccessibilityValue(shown.spoken)
    }
}
