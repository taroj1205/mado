import AppKit

final class WidgetTrack: NSView {
    private struct Controls {
        let skip: CGFloat
        let space: CGFloat

        var width: CGFloat {
            skip + skip + WidgetDisc.size + space + space
        }
    }

    private static let lineGap: CGFloat = 2
    private static let coverGap: CGFloat = 12
    private static let columnGap: CGFloat = 16
    private static let controlsGap: CGFloat = 8
    private static let gap: CGFloat = 10
    private static let skipReach: CGFloat = 4
    private static let skipAlpha = (dark: 0.8, light: 0.72)
    private static let skipTone = WidgetTile.tone(.white, .black, skipAlpha)
    private static let boxScale: CGFloat = 1.5
    private static let nudge: CGFloat = 3
    private static let nudgeSeconds = 0.24
    private static let artShare: CGFloat = 0.45
    private static let tallestArt: CGFloat = 96
    private static let shortestLines: CGFloat = 70
    private static let half: CGFloat = 0.5
    private static let lookupBar = (width: 150.0, height: 8.0)
    static let short = (title: 14.0, artist: 12.0, skip: 11.0, space: 3.0)
    private static let tall = (title: 16.0, artist: 13.0, skip: 15.0, space: 10.0)

    let cover = WidgetCover()
    let title = NSTextField(labelWithString: "")
    let artist = NSTextField(labelWithString: "")
    let paused = NSTextField(labelWithString: "")
    let lyric = LyricLine()
    let lookup = WidgetSkeleton(fraction: 1, height: lookupBar.height)
    let equalizer = WidgetEqualizer()
    let disc = WidgetDisc()
    let previous = WidgetTrack.symbol("backward.fill")
    let next = WidgetTrack.symbol("forward.fill")
    private(set) var tint: NSColor?
    private var shown: WidgetGrid.Track?

    var form = WidgetForm(size: .zero) {
        didSet {
            guard form != oldValue else { return }
            restyle()
            showLines()
            needsLayout = true
        }
    }

    override var isFlipped: Bool { true }

    private var eyebrowHeight: CGFloat {
        paused.intrinsicContentSize.height
    }

    private var showsLyric: Bool {
        (shown?.lyric != nil || shown?.lookingUp == true) && !form.tall && form.reach == .wide
    }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        title.textColor = .labelColor
        artist.textColor = .secondaryLabelColor
        paused.attributedStringValue = NSAttributedString(
            string: WidgetInk.eyebrow.shown("Paused"), attributes: WidgetInk.eyebrow.attributes)
        for label in [title, artist] {
            label.lineBreakMode = .byTruncatingTail
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        for view in [cover, equalizer, paused, disc, lyric, lookup] {
            view.translatesAutoresizingMaskIntoConstraints = true
        }
        lyric.isHidden = true
        lookup.isHidden = true
        [cover, equalizer, paused, title, artist, lyric, lookup, previous, disc, next]
            .forEach(addSubview)
        restyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func symbol(_ name: String) -> NSImageView {
        let view = NSImageView(
            image: NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage())
        view.contentTintColor = skipTone
        view.wantsLayer = true
        return view
    }

    override func layout() {
        super.layout()
        let style = form.tall ? Self.tall : Self.short
        let controls = Controls(skip: style.skip * Self.boxScale, space: style.space)
        let lines =
            showsLyric
            ? title.intrinsicContentSize.height + Self.lineGap + lyric.intrinsicContentSize.height
            : eyebrowHeight + title.intrinsicContentSize.height
                + artist.intrinsicContentSize.height + Self.lineGap + Self.lineGap
        if form.tall {
            layOutTall(controls: controls, lines: lines)
        } else {
            layOutShort(controls: controls, lines: lines)
        }
    }

    func skip(at point: NSPoint) -> WidgetGrid.Skip? {
        let reach = -Self.skipReach
        if previous.isHidden || next.isHidden { return nil }
        if convert(previous.bounds, from: previous).insetBy(dx: reach, dy: reach).contains(point) {
            return .previous
        }
        if convert(next.bounds, from: next).insetBy(dx: reach, dy: reach).contains(point) {
            return .next
        }
        return nil
    }

    func pressesDisc(at point: NSPoint) -> Bool {
        !disc.isHidden && convert(disc.bounds, from: disc).contains(point)
    }

    func pulse(_ skip: WidgetGrid.Skip) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let reach = skip == .previous ? -Self.nudge : Self.nudge
        let push = CAKeyframeAnimation(keyPath: "transform.translation.x")
        push.values = [0, reach, 0]
        push.timingFunctions = [CAMediaTimingFunction(name: .easeOut), .init(name: .easeIn)]
        push.duration = Self.nudgeSeconds
        (skip == .previous ? previous : next).layer?.add(push, forKey: "pulse")
    }

    func show(_ track: WidgetGrid.Track) {
        let first = shown == nil
        let flipped = shown?.isPlaying != track.isPlaying
        title.stringValue = track.title
        artist.stringValue = track.artist
        equalizer.isActive = track.isPlaying
        if flipped {
            disc.show(playing: track.isPlaying, animated: !first)
            cover.setPlaying(track.isPlaying, animated: !first)
        }
        if first || shown?.artwork != track.artwork {
            let image = track.artwork.flatMap(NSImage.init(data:))
            tint = image.flatMap(ArtworkTint.of)
            cover.show(image, tint: tint, animated: !first)
        }
        shown = track
        if let line = track.lyric { lyric.show(line, playing: track.isPlaying) }
        showLines()
    }

    private func showLines() {
        let visible = showsLyric
        equalizer.isHidden = visible || shown?.isPlaying != true
        paused.isHidden = visible || shown?.isPlaying != false
        artist.isHidden = visible
        lyric.isHidden = !visible || shown?.lyric == nil
        lookup.isHidden = !visible || shown?.lookingUp != true
        guard let shown else { return }
        if visible {
            title.attributedStringValue = Self.heading(shown)
        } else {
            restyle()
            title.stringValue = shown.title
        }
        needsLayout = true
    }

    private func restyle() {
        let style = form.tall ? Self.tall : Self.short
        title.font = .systemFont(ofSize: style.title, weight: .semibold)
        artist.font = .systemFont(ofSize: style.artist)
        for glyph in [previous, next] {
            glyph.symbolConfiguration = .init(pointSize: style.skip, weight: .medium)
        }
    }

    private func layOutShort(controls: Controls, lines: CGFloat) {
        let side = min(WidgetCover.size, bounds.height)
        let start = side + Self.coverGap
        let fits = bounds.width - start - Self.controlsGap - controls.width >= Self.shortestLines
        let width = fits ? controls.width : WidgetDisc.size
        let end = bounds.width - width
        cover.frame = NSRect(
            x: 0, y: (bounds.height - side) * Self.half, width: side, height: side)
        placeLines(
            NSRect(
                x: start, y: (bounds.height - lines) * Self.half,
                width: max(end - Self.controlsGap - start, 0), height: lines))
        placeControls(
            controls, showsSkips: fits,
            at: NSPoint(x: end, y: (bounds.height - WidgetDisc.size) * Self.half))
    }

    private func layOutTall(controls: Controls, lines: CGFloat) {
        let side = min(
            bounds.height - WidgetDisc.size - Self.gap, bounds.width * Self.artShare,
            Self.tallestArt)
        let room = bounds.width - controls.skip - controls.skip - WidgetDisc.size
        let spaced = Controls(skip: controls.skip, space: min(controls.space, room * Self.half))
        let start = side + Self.columnGap
        cover.frame = NSRect(x: 0, y: 0, width: side, height: side)
        placeLines(
            NSRect(
                x: start, y: (side - lines) * Self.half, width: max(bounds.width - start, 0),
                height: lines))
        placeControls(
            spaced, showsSkips: true,
            at: NSPoint(
                x: (bounds.width - spaced.width) * Self.half,
                y: bounds.height - WidgetDisc.size))
    }

    private func placeLines(_ frame: NSRect) {
        let titleHeight = title.intrinsicContentSize.height
        if showsLyric {
            place(
                title,
                in: NSRect(x: frame.minX, y: frame.minY, width: frame.width, height: titleHeight))
            lyric.frame = NSRect(
                x: frame.minX, y: frame.minY + titleHeight + Self.lineGap, width: frame.width,
                height: lyric.intrinsicContentSize.height)
            lookup.frame = NSRect(
                x: frame.minX,
                y: lyric.frame.midY - Self.lookupBar.height * Self.half,
                width: min(frame.width, Self.lookupBar.width), height: Self.lookupBar.height)
            return
        }
        place(
            paused,
            in: NSRect(
                x: frame.minX, y: frame.minY,
                width: min(paused.intrinsicContentSize.width, frame.width),
                height: eyebrowHeight))
        equalizer.frame = NSRect(
            x: frame.minX,
            y: frame.minY + paused.firstBaselineOffsetFromTop - WidgetEqualizer.height,
            width: equalizer.intrinsicContentSize.width, height: WidgetEqualizer.height)
        let top = frame.minY + eyebrowHeight + Self.lineGap
        place(title, in: NSRect(x: frame.minX, y: top, width: frame.width, height: titleHeight))
        place(
            artist,
            in: NSRect(
                x: frame.minX, y: top + titleHeight + Self.lineGap, width: frame.width,
                height: artist.intrinsicContentSize.height))
    }

    private func place(_ label: NSTextField, in rect: NSRect) {
        label.frame = label.frame(forAlignmentRect: rect)
    }

    private func placeControls(_ controls: Controls, showsSkips: Bool, at origin: NSPoint) {
        previous.isHidden = !showsSkips
        next.isHidden = !showsSkips
        var left = origin.x
        if showsSkips {
            previous.frame = NSRect(
                x: left, y: origin.y, width: controls.skip, height: WidgetDisc.size)
            left += controls.skip + controls.space
        }
        disc.frame = NSRect(x: left, y: origin.y, width: WidgetDisc.size, height: WidgetDisc.size)
        left += WidgetDisc.size + controls.space
        if showsSkips {
            next.frame = NSRect(x: left, y: origin.y, width: controls.skip, height: WidgetDisc.size)
        }
    }
}
