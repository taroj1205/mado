import AppKit

final class LyricsDesktop: NSView {
    struct Style {
        private static let desktopRest: CGFloat = 15
        private static let desktopLine: CGFloat = 26
        private static let desktopGap: CGFloat = 6
        private static let dockRest: CGFloat = 12
        private static let dockLine: CGFloat = 20
        private static let dockGap: CGFloat = 4
        static let desktop = Self(rest: desktopRest, line: desktopLine, gap: desktopGap)
        static let dock = Self(rest: dockRest, line: dockLine, gap: dockGap)

        let rest: CGFloat
        let line: CGFloat
        let gap: CGFloat
    }

    let previous: NSTextField
    let line: LyricLine
    let next: NSTextField
    var reducesMotion = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    private let stack: NSStackView
    private var text: LyricsFloatText?

    convenience init() {
        self.init(style: .desktop)
    }

    init(style: Style) {
        previous = Self.rest(size: style.rest)
        line = LyricLine(size: style.line, weight: .semibold)
        next = Self.rest(size: style.rest)
        stack = NSStackView(views: [previous, line, next])
        super.init(frame: .zero)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = style.gap
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

    private static func rest(size: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: size)
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
