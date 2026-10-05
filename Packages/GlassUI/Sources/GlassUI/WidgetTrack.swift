import AppKit

final class WidgetTrack: NSView {
    private struct Controls {
        let skip: CGFloat
        let box: CGFloat
        let space: CGFloat

        var size: CGSize {
            CGSize(width: skip + skip + box + space + space, height: box)
        }
    }

    private static let artSize: CGFloat = 48
    private static let artRadius: CGFloat = 9
    private static let noteSize: CGFloat = 20
    private static let tallNote: CGFloat = 32
    private static let lineGap: CGFloat = 2
    private static let gap: CGFloat = 10
    private static let columnGap: CGFloat = 14
    private static let skipReach: CGFloat = 5
    private static let boxScale: CGFloat = 1.5
    private static let artShare: CGFloat = 0.38
    private static let tallestArt: CGFloat = 96
    private static let stackedArt: CGFloat = 64
    private static let artAlpha = (dark: 0.10, light: 0.06)
    private static let artFill = WidgetTile.tone(.white, .black, artAlpha)
    private static let half: CGFloat = 0.5
    private static let short = (title: 13.5, artist: 12.0, skip: 13.0, toggle: 15.0, space: 10.0)
    private static let tall = (title: 15.0, artist: 13.0, skip: 17.0, toggle: 21.0, space: 26.0)

    let art = NSImageView()
    let title = NSTextField(labelWithString: "")
    let artist = NSTextField(labelWithString: "")
    let toggle = NSImageView()
    let previous = NSImageView()
    let next = NSImageView()
    private let placeholder = NSBox()
    private var artwork: Data?
    private var playing: WidgetGrid.Track?

    var form = WidgetForm(size: .zero) {
        didSet {
            guard form != oldValue else { return }
            restyle()
            needsLayout = true
        }
    }

    override var isFlipped: Bool { true }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        placeholder.boxType = .custom
        placeholder.cornerRadius = Self.artRadius
        placeholder.borderWidth = 0
        placeholder.fillColor = Self.artFill
        art.wantsLayer = true
        art.layer?.cornerRadius = Self.artRadius
        art.layer?.masksToBounds = true
        title.textColor = .labelColor
        artist.textColor = .secondaryLabelColor
        for label in [title, artist] {
            label.lineBreakMode = .byTruncatingTail
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        for glyph in [previous, toggle, next] {
            glyph.contentTintColor = .labelColor
        }
        previous.image = NSImage(systemSymbolName: "backward.end", accessibilityDescription: nil)
        next.image = NSImage(systemSymbolName: "forward.end", accessibilityDescription: nil)
        [placeholder, art, title, artist, previous, toggle, next].forEach(addSubview)
        restyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private func restyle() {
        let style = form.tall ? Self.tall : Self.short
        title.font = .systemFont(ofSize: style.title, weight: .semibold)
        artist.font = .systemFont(ofSize: style.artist)
        previous.symbolConfiguration = .init(pointSize: style.skip, weight: .semibold)
        next.symbolConfiguration = .init(pointSize: style.skip, weight: .semibold)
        toggle.symbolConfiguration = .init(pointSize: style.toggle, weight: .semibold)
        showArtwork()
    }

    override func layout() {
        super.layout()
        let style = form.tall ? Self.tall : Self.short
        let controls = Controls(
            skip: style.skip * Self.boxScale, box: style.toggle * Self.boxScale,
            space: style.space)
        let lines =
            title.intrinsicContentSize.height + Self.lineGap
            + artist.intrinsicContentSize.height
        if !form.tall {
            layOutShort(controls: controls, lines: lines)
        } else if form.reach == .narrow {
            layOutStacked(controls: controls, lines: lines)
        } else {
            layOutWide(controls: controls, lines: lines, space: style.space)
        }
    }

    private func layOutShort(controls: Controls, lines: CGFloat) {
        let side = Self.artSize
        let start = side + Self.gap
        let end = bounds.width - controls.size.width
        placeArt(NSRect(x: 0, y: (bounds.height - side) * Self.half, width: side, height: side))
        placeLines(
            NSRect(
                x: start, y: (bounds.height - lines) * Self.half,
                width: max(end - Self.gap - start, 0), height: lines))
        placeControls(
            controls, at: NSPoint(x: end, y: (bounds.height - controls.box) * Self.half))
    }

    private func layOutStacked(controls: Controls, lines: CGFloat) {
        let side = Self.stackedArt
        let room = (bounds.width - controls.skip - controls.skip - controls.box) * Self.half
        placeArt(NSRect(x: 0, y: 0, width: side, height: side))
        placeLines(NSRect(x: 0, y: side + Self.gap, width: bounds.width, height: lines))
        placeControls(
            Controls(skip: controls.skip, box: controls.box, space: room),
            at: NSPoint(x: 0, y: bounds.height - controls.box))
    }

    private func layOutWide(controls: Controls, lines: CGFloat, space: CGFloat) {
        let side = min(bounds.height, bounds.width * Self.artShare, Self.tallestArt)
        let top = (bounds.height - side) * Self.half
        let start = side + Self.columnGap
        let room = (bounds.width - start - controls.skip - controls.skip - controls.box) * Self.half
        placeArt(NSRect(x: 0, y: top, width: side, height: side))
        placeLines(
            NSRect(x: start, y: top + Self.gap, width: bounds.width - start, height: lines))
        placeControls(
            Controls(skip: controls.skip, box: controls.box, space: min(space, room)),
            at: NSPoint(x: start, y: top + side - controls.box - Self.gap))
    }

    private func placeArt(_ frame: NSRect) {
        placeholder.frame = frame
        art.frame = frame
        showArtwork()
    }

    private func placeLines(_ frame: NSRect) {
        let titleHeight = title.intrinsicContentSize.height
        title.frame = NSRect(
            x: frame.minX, y: frame.minY, width: frame.width, height: titleHeight)
        artist.frame = NSRect(
            x: frame.minX, y: frame.minY + titleHeight + Self.lineGap, width: frame.width,
            height: artist.intrinsicContentSize.height)
    }

    private func placeControls(_ controls: Controls, at origin: NSPoint) {
        var left = origin.x
        let glyphs = [(previous, controls.skip), (toggle, controls.box), (next, controls.skip)]
        for (glyph, width) in glyphs {
            glyph.frame = NSRect(x: left, y: origin.y, width: width, height: controls.box)
            left += width + controls.space
        }
    }

    func skip(at point: NSPoint) -> WidgetGrid.Skip? {
        let reach = -Self.skipReach
        if convert(previous.bounds, from: previous).insetBy(dx: reach, dy: reach).contains(point) {
            return .previous
        }
        if convert(next.bounds, from: next).insetBy(dx: reach, dy: reach).contains(point) {
            return .next
        }
        return nil
    }

    func show(_ track: WidgetGrid.Track) {
        playing = track
        title.stringValue = track.title
        artist.stringValue = track.artist
        toggle.image = NSImage(
            systemSymbolName: track.isPlaying ? "pause" : "play",
            accessibilityDescription: nil)
        guard track.artwork != artwork || art.image == nil else { return }
        artwork = track.artwork
        showArtwork()
    }

    private func showArtwork() {
        guard let playing else { return }
        if let image = playing.artwork.flatMap(NSImage.init(data:)) {
            art.image = image
            art.imageScaling = .scaleProportionallyUpOrDown
            art.symbolConfiguration = nil
        } else {
            art.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
            art.imageScaling = .scaleNone
            art.symbolConfiguration = .init(
                pointSize: form.tall ? Self.tallNote : Self.noteSize, weight: .regular)
            art.contentTintColor = .secondaryLabelColor
        }
    }
}
