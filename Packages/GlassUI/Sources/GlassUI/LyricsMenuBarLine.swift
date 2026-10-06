public import AppKit

public final class LyricsMenuBarLine: NSView {
    public static let width: CGFloat = 210
    private static let height = LyricsBarSpot.height
    private static let inset: CGFloat = 8
    private static let gap: CGFloat = 7
    private static let radius: CGFloat = 6
    private static let size: CGFloat = 12
    private static let half: CGFloat = 0.5
    private static let pillAlpha = (dark: 0.2, light: 0.1)
    private static let pill = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? .white.withAlphaComponent(pillAlpha.dark)
            : .black.withAlphaComponent(pillAlpha.light)
    }

    let equalizer = WidgetEqualizer()
    let line = LyricLine(size: size, weight: .medium)
    var reducesMotion = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    private var text: String?

    override public var wantsUpdateLayer: Bool { true }

    override public var intrinsicContentSize: NSSize {
        NSSize(width: Self.width, height: Self.height)
    }

    public init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = Self.radius
        layer?.cornerCurve = .continuous
        for view in [equalizer, line] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = true
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

    override public func layout() {
        super.layout()
        let bars = equalizer.intrinsicContentSize
        equalizer.frame = NSRect(
            x: Self.inset, y: ((bounds.height - bars.height) * Self.half).rounded(),
            width: bars.width, height: bars.height)
        let left = equalizer.frame.maxX + Self.gap
        let tall = line.intrinsicContentSize.height
        line.frame = NSRect(
            x: left, y: ((bounds.height - tall) * Self.half).rounded(),
            width: max(bounds.width - left - Self.inset, 0), height: tall)
    }

    override public func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = Self.pill.cgColor
        }
    }

    override public func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    public func show(_ verse: WidgetGrid.Verse) {
        let shown = LyricsFloatText(verse)
        if equalizer.isActive != verse.isPlaying {
            equalizer.isActive = verse.isPlaying
        }
        let words = shown.lyric(of: verse)
        let changed = words.text != text
        if changed, text != nil, reducesMotion() {
            LyricsCard.crossFade(line.layer, seconds: LyricsCard.swapSeconds)
        }
        text = words.text
        line.show(words, playing: verse.isPlaying)
        setAccessibilityValue(shown.spoken)
    }
}
