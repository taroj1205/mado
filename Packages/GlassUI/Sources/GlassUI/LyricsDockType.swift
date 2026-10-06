import AppKit

final class LyricsDockType: NSView {
    private static let restSize: CGFloat = 12
    private static let lineSize: CGFloat = 20
    private static let gap: CGFloat = 4
    private static let lyricLines = 4
    private static let contextLines = 2
    private static let restFont = NSFont.systemFont(ofSize: restSize)

    let previous: NSTextField
    let line: LyricLine
    let next: NSTextField
    var reducesMotion = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    private var text: LyricsFloatText?

    init() {
        previous = Self.rest()
        line = LyricLine(size: Self.lineSize, weight: .semibold, lines: Self.lyricLines)
        next = Self.rest()
        super.init(frame: .zero)
        line.translatesAutoresizingMaskIntoConstraints = true
        line.wantsLayer = true
        for view in [previous, line, next] as [NSView] {
            addSubview(view)
        }
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Lyrics")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func rest(_ text: String?) -> NSAttributedString {
        LyricsWrap.string(text ?? "", font: restFont, color: .tertiaryLabelColor)
    }

    private static func rest() -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: "")
        label.isSelectable = false
        label.font = restFont
        label.maximumNumberOfLines = contextLines
        label.cell?.truncatesLastVisibleLine = true
        return label
    }

    override func layout() {
        super.layout()
        var bottom: CGFloat = 0
        for row in rows(fitting: bounds.width) {
            row.view.frame = NSRect(x: 0, y: bottom, width: bounds.width, height: row.height)
            bottom += row.height + Self.gap
        }
    }

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    func show(_ verse: WidgetGrid.Verse) {
        let shown = LyricsFloatText(verse)
        if text?.line != shown.line, text != nil, reducesMotion() {
            LyricsCard.crossFade(line.layer, seconds: LyricsCard.swapSeconds)
        }
        text = shown
        previous.attributedStringValue = Self.rest(shown.previous)
        next.attributedStringValue = Self.rest(shown.next)
        line.show(shown.lyric(of: verse), playing: verse.isPlaying)
        needsLayout = true
        setAccessibilityValue(shown.spoken)
    }

    func contentHeight(for width: CGFloat) -> CGFloat {
        rows(fitting: width).reduce(0) { $0 + $1.height + Self.gap } - Self.gap
    }

    private func rows(fitting width: CGFloat) -> [(view: NSView, height: CGFloat)] {
        [
            (next, height(of: next, fitting: width)), (line, line.height(for: width)),
            (previous, height(of: previous, fitting: width)),
        ]
    }

    private func height(of label: NSTextField, fitting width: CGFloat) -> CGFloat {
        let wrapped = LyricsWrap(
            label.stringValue, font: Self.restFont, width: width, lines: Self.contextLines)
        return max(LyricsWrap.lineHeight(of: Self.restFont), wrapped.height)
    }
}
