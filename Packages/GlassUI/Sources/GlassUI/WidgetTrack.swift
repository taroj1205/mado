import AppKit

final class WidgetTrack: NSView {
    private static let titleSize: CGFloat = 14
    private static let artistSize: CGFloat = 12
    private static let pausedSize: CGFloat = 10
    private static let pausedKern: CGFloat = 0.8
    private static let eyebrowHeight: CGFloat = 12
    private static let lineGap: CGFloat = 2
    private static let coverGap: CGFloat = 10
    private static let controlsGap: CGFloat = 6
    private static let buttonGap: CGFloat = 5
    private static let skipReach: CGFloat = 4
    private static let skipSize: CGFloat = 11
    private static let skipAlpha = (dark: 0.8, light: 0.72)
    private static let skipTone = WidgetTile.tone(.white, .black, skipAlpha)
    private static let nudge: CGFloat = 3
    private static let nudgeSeconds = 0.24

    let cover = WidgetCover()
    let title = NSTextField(labelWithString: "")
    let artist = NSTextField(labelWithString: "")
    let paused = NSTextField(labelWithString: "")
    let equalizer = WidgetEqualizer()
    let disc = WidgetDisc()
    let previous = WidgetTrack.symbol("backward.fill")
    let next = WidgetTrack.symbol("forward.fill")
    private(set) var tint: NSColor?
    private var shown: WidgetGrid.Track?

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        title.font = .systemFont(ofSize: Self.titleSize, weight: .semibold)
        title.textColor = .labelColor
        artist.font = .systemFont(ofSize: Self.artistSize)
        artist.textColor = .secondaryLabelColor
        paused.attributedStringValue = NSAttributedString(
            string: "PAUSED",
            attributes: [
                .font: NSFont.systemFont(ofSize: Self.pausedSize, weight: .semibold),
                .foregroundColor: NSColor.tertiaryLabelColor,
                .kern: Self.pausedKern,
            ])
        for label in [title, artist] {
            label.lineBreakMode = .byTruncatingTail
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        let eyebrow = NSStackView(views: [equalizer, paused])
        eyebrow.heightAnchor.constraint(equalToConstant: Self.eyebrowHeight).isActive = true
        let lines = NSStackView(views: [eyebrow, title, artist])
        lines.orientation = .vertical
        lines.alignment = .leading
        lines.spacing = Self.lineGap
        let controls = NSStackView(views: [previous, disc, next])
        controls.spacing = Self.buttonGap
        controls.setContentCompressionResistancePriority(.required, for: .horizontal)
        layOut(lines, controls)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func symbol(_ name: String) -> NSImageView {
        let view = NSImageView(
            image: NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage())
        view.symbolConfiguration = .init(pointSize: skipSize, weight: .medium)
        view.contentTintColor = skipTone
        view.wantsLayer = true
        return view
    }

    private func layOut(_ lines: NSView, _ controls: NSView) {
        for view in [cover, lines, controls] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            cover.leadingAnchor.constraint(equalTo: leadingAnchor),
            cover.centerYAnchor.constraint(equalTo: centerYAnchor),
            lines.leadingAnchor.constraint(equalTo: cover.trailingAnchor, constant: Self.coverGap),
            lines.centerYAnchor.constraint(equalTo: centerYAnchor),
            controls.leadingAnchor.constraint(
                equalTo: lines.trailingAnchor, constant: Self.controlsGap),
            controls.trailingAnchor.constraint(equalTo: trailingAnchor),
            controls.centerYAnchor.constraint(equalTo: centerYAnchor),
            topAnchor.constraint(equalTo: cover.topAnchor),
            bottomAnchor.constraint(equalTo: cover.bottomAnchor),
        ])
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
        equalizer.isHidden = !track.isPlaying
        paused.isHidden = track.isPlaying
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
    }
}
