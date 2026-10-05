import AppKit

final class LyricsPaneTrack: NSView {
    private static let titleGap: CGFloat = 14
    private static let titleSize: CGFloat = 16
    private static let artistGap: CGFloat = 2
    private static let artistSize: CGFloat = 13
    private static let progressGap: CGFloat = 16
    private static let transportGap: CGFloat = 12
    private static let controlGap: CGFloat = 22
    private static let skipSize: CGFloat = 15
    private static let skipBox: CGFloat = 29
    private static let discSize: CGFloat = 40
    private static let glyphSize: CGFloat = 15
    private static let glyphAlpha = (dark: 0.88, light: 1.0)
    private static let glyph = WidgetTile.tone(.black, .white, glyphAlpha)
    private static let half: CGFloat = 0.5
    private static let previousLabel = "Previous track"
    private static let nextLabel = "Next track"

    let cover = LyricsPaneCover()
    let title = NSTextField(labelWithString: "")
    let artist = NSTextField(labelWithString: "")
    let progress = LyricsPaneProgress()
    let previous = LyricsPaneTrack.button("backward.end", size: skipSize, label: previousLabel)
    let next = LyricsPaneTrack.button("forward.end", size: skipSize, label: nextLabel)
    let play = LyricsPaneTrack.button("pause.fill", size: glyphSize, label: "")
    var onSkip: ((WidgetGrid.Skip) -> Void)?
    var onPlayPause: (() -> Void)?
    private let disc = NSBox()
    private var artwork: Data?

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        title.font = .systemFont(ofSize: Self.titleSize, weight: .semibold)
        artist.font = .systemFont(ofSize: Self.artistSize)
        artist.textColor = .secondaryLabelColor
        for label in [title, artist] {
            label.lineBreakMode = .byTruncatingTail
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        disc.boxType = .custom
        disc.borderWidth = 0
        disc.cornerRadius = Self.discSize * Self.half
        disc.fillColor = .labelColor
        disc.contentViewMargins = .zero
        disc.contentView = play
        play.contentTintColor = Self.glyph
        for (button, action) in [
            (previous, #selector(skipBack)), (play, #selector(playPause)),
            (next, #selector(skipAhead)),
        ] {
            button.target = self
            button.action = action
        }
        layOut()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func button(_ symbol: String, size: CGFloat, label: String) -> NSButton {
        let button = NSButton()
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.refusesFirstResponder = true
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        button.symbolConfiguration = .init(pointSize: size, weight: .semibold)
        button.contentTintColor = .labelColor
        button.setAccessibilityLabel(label)
        return button
    }

    func show(_ verse: WidgetGrid.Verse) {
        title.stringValue = verse.title
        artist.stringValue = verse.artist
        if verse.artwork != artwork {
            artwork = verse.artwork
            cover.show(verse.artwork.flatMap(NSImage.init(data:)))
        }
        play.image = NSImage(
            systemSymbolName: verse.isPlaying ? "pause.fill" : "play.fill",
            accessibilityDescription: nil)
        play.setAccessibilityLabel(verse.isPlaying ? "Pause" : "Play")
        progress.show(position: verse.position, duration: verse.duration, playing: verse.isPlaying)
    }

    @objc
    private func skipBack() {
        onSkip?(.previous)
    }

    @objc
    private func skipAhead() {
        onSkip?(.next)
    }

    @objc
    private func playPause() {
        onPlayPause?()
    }

    private func layOut() {
        let transport = NSStackView(views: [previous, disc, next])
        transport.spacing = Self.controlGap
        for view in [cover, title, artist, progress, transport] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            cover.topAnchor.constraint(equalTo: topAnchor),
            cover.leadingAnchor.constraint(equalTo: leadingAnchor),
            cover.widthAnchor.constraint(equalToConstant: LyricsPaneCover.size),
            cover.heightAnchor.constraint(equalToConstant: LyricsPaneCover.size),
            widthAnchor.constraint(equalTo: cover.widthAnchor),
            title.topAnchor.constraint(equalTo: cover.bottomAnchor, constant: Self.titleGap),
            artist.topAnchor.constraint(equalTo: title.bottomAnchor, constant: Self.artistGap),
            progress.topAnchor.constraint(
                equalTo: artist.bottomAnchor, constant: Self.progressGap),
            transport.topAnchor.constraint(
                equalTo: progress.bottomAnchor, constant: Self.transportGap),
            transport.centerXAnchor.constraint(equalTo: centerXAnchor),
            disc.widthAnchor.constraint(equalToConstant: Self.discSize),
            disc.heightAnchor.constraint(equalToConstant: Self.discSize),
            previous.widthAnchor.constraint(equalToConstant: Self.skipBox),
            previous.heightAnchor.constraint(equalToConstant: Self.skipBox),
            next.widthAnchor.constraint(equalToConstant: Self.skipBox),
            next.heightAnchor.constraint(equalToConstant: Self.skipBox),
        ])
        for view in [title, artist, progress] {
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: leadingAnchor),
                view.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
        }
    }
}
