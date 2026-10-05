import AppKit

final class LyricsCard: NSView {
    enum Drag {
        case began
        case ended
        case moved
    }

    static let chipSize: CGFloat = 24
    static let coverSize: CGFloat = 40
    private static let coverRadius: CGFloat = 8
    private static let lineSize: CGFloat = 13
    private static let titleSize: CGFloat = 14
    private static let artistSize: CGFloat = 12
    private static let lyricSize: CGFloat = 17
    private static let followingSize: CGFloat = 13
    private static let skipSize: CGFloat = 11
    private static let playSize: CGFloat = 12
    private static let pitch: CGFloat = 36
    private static let restSize: CGFloat = 13.3
    static let growSeconds = 0.45
    static let swapSeconds = 0.25
    private static let half: CGFloat = 0.5
    private static let note = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)

    let chip = LyricsCard.cover(radius: chipSize * half)
    let line = LyricLine(size: lineSize, weight: .medium)
    let cover = LyricsCard.cover(radius: coverRadius)
    let title = LyricsCard.label(size: titleSize, weight: .semibold, color: .labelColor)
    let artist = LyricsCard.label(size: artistSize, weight: .regular, color: .secondaryLabelColor)
    let previous = LyricsCardButton(size: skipSize, label: "Previous track")
    let playPause = LyricsCardButton(size: playSize, label: "Pause")
    let next = LyricsCardButton(size: skipSize, label: "Next track")
    let lyric = LyricLine(size: lyricSize, weight: .medium)
    let following = LyricsCard.label(
        size: followingSize, weight: .regular, color: .secondaryLabelColor)
    let column = LyricsColumn(look: .init(pitch: pitch, size: lyricSize, rest: restSize))
    var onControl: ((LyricsControl) -> Void)?
    var onDrag: ((Drag) -> Void)?
    var reducesMotion = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    private(set) var look = LyricsLook.line
    private(set) var text: LyricsFloatText?
    private var artwork: Data?
    private var showsPause = true

    override var isFlipped: Bool { true }

    var controls: [LyricsCardButton] {
        [previous, playPause, next]
    }

    var header: [NSView] {
        [cover, title, artist] + controls
    }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        previous.show(symbol: "backward.end", label: "Previous track")
        next.show(symbol: "forward.end", label: "Next track")
        playPause.show(symbol: "pause", label: "Pause")
        previous.onPress = { [weak self] in self?.onControl?(.previous) }
        playPause.onPress = { [weak self] in self?.onControl?(.playPause) }
        next.onPress = { [weak self] in self?.onControl?(.next) }
        for view in [line, lyric, column] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = true
            view.wantsLayer = true
        }
        ([chip, line, following, lyric, column] + header).forEach(addSubview)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Lyrics")
        showArtwork(nil)
        setLook(.line, animated: false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func cover(radius: CGFloat) -> NSImageView {
        let view = NSImageView()
        view.wantsLayer = true
        view.layer?.cornerRadius = radius
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        view.contentTintColor = .secondaryLabelColor
        return view
    }

    private static func label(size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    static func crossFade(_ layer: CALayer?, seconds: CFTimeInterval) {
        let fade = CATransition()
        fade.type = .fade
        fade.duration = seconds
        layer?.add(fade, forKey: "swap")
    }

    override func layout() {
        super.layout()
        arrange()
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with _: NSEvent) {
        onDrag?(.began)
    }

    override func mouseDragged(with _: NSEvent) {
        onDrag?(.moved)
    }

    override func mouseUp(with _: NSEvent) {
        onDrag?(.ended)
    }

    func setLook(_ look: LyricsLook, animated: Bool) {
        if animated, look != self.look {
            Self.crossFade(layer, seconds: Self.growSeconds)
        }
        self.look = look
        reveal()
        needsLayout = true
    }

    func show(_ verse: WidgetGrid.Verse) {
        let shown = LyricsFloatText(verse)
        if text?.line != shown.line, text != nil, reducesMotion() {
            [line, lyric].forEach { Self.crossFade($0.layer, seconds: Self.swapSeconds) }
        }
        text = shown
        title.stringValue = verse.title
        artist.stringValue = verse.artist
        let playing = verse.isPlaying
        if playing != showsPause {
            showsPause = playing
            playPause.show(symbol: playing ? "pause" : "play", label: playing ? "Pause" : "Play")
        }
        if artwork != verse.artwork {
            artwork = verse.artwork
            showArtwork(verse.artwork.flatMap(NSImage.init(data:)))
        }
        let words = shown.lyric(of: verse)
        line.show(words, playing: playing)
        lyric.show(words, playing: playing)
        following.stringValue = shown.next ?? ""
        column.show(
            shown.lines, current: shown.current, progress: verse.progress,
            remaining: verse.remaining, playing: playing)
        setAccessibilityValue(shown.spoken)
        reveal()
    }

    private func showArtwork(_ image: NSImage?) {
        for view in [chip, cover] {
            view.image = image ?? Self.note
            view.imageScaling = image == nil ? .scaleNone : .scaleAxesIndependently
        }
    }
}
