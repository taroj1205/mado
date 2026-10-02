import AppKit

final class WidgetTrack: NSView {
    private static let artSize: CGFloat = 48
    private static let artRadius: CGFloat = 9
    private static let noteSize: CGFloat = 20
    private static let titleSize: CGFloat = 13.5
    private static let artistSize: CGFloat = 12
    private static let lineGap: CGFloat = 2
    private static let gap: CGFloat = 10
    private static let skipSize: CGFloat = 13
    private static let toggleSize: CGFloat = 15
    private static let toggleWidth: CGFloat = 20
    private static let artAlpha = (dark: 0.10, light: 0.06)
    private static let artFill = WidgetTile.tone(.white, .black, artAlpha)

    let art = NSImageView()
    let title = NSTextField(labelWithString: "")
    let artist = NSTextField(labelWithString: "")
    let toggle = NSImageView()
    private let placeholder = NSBox()
    private var artwork: Data?

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
        title.font = .systemFont(ofSize: Self.titleSize, weight: .semibold)
        title.textColor = .labelColor
        artist.font = .systemFont(ofSize: Self.artistSize)
        artist.textColor = .secondaryLabelColor
        let lines = NSStackView(views: [title, artist])
        lines.orientation = .vertical
        lines.alignment = .leading
        lines.spacing = Self.lineGap
        let controls = NSStackView(views: [
            Self.symbol("backward.end", size: Self.skipSize), toggle,
            Self.symbol("forward.end", size: Self.skipSize),
        ])
        controls.spacing = Self.gap
        controls.setContentCompressionResistancePriority(.required, for: .horizontal)
        toggle.symbolConfiguration = .init(pointSize: Self.toggleSize, weight: .semibold)
        toggle.contentTintColor = .labelColor
        for label in [title, artist] {
            label.lineBreakMode = .byTruncatingTail
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        layOut(lines, controls)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func symbol(_ name: String, size: CGFloat) -> NSImageView {
        let view = NSImageView(
            image: NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage())
        view.symbolConfiguration = .init(pointSize: size, weight: .semibold)
        view.contentTintColor = .labelColor
        return view
    }

    private func layOut(_ lines: NSView, _ controls: NSView) {
        for view in [placeholder, art, lines, controls] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            placeholder.leadingAnchor.constraint(equalTo: leadingAnchor),
            placeholder.centerYAnchor.constraint(equalTo: centerYAnchor),
            placeholder.widthAnchor.constraint(equalToConstant: Self.artSize),
            placeholder.heightAnchor.constraint(equalToConstant: Self.artSize),
            art.leadingAnchor.constraint(equalTo: placeholder.leadingAnchor),
            art.trailingAnchor.constraint(equalTo: placeholder.trailingAnchor),
            art.topAnchor.constraint(equalTo: placeholder.topAnchor),
            art.bottomAnchor.constraint(equalTo: placeholder.bottomAnchor),
            lines.leadingAnchor.constraint(equalTo: placeholder.trailingAnchor, constant: Self.gap),
            lines.centerYAnchor.constraint(equalTo: centerYAnchor),
            controls.leadingAnchor.constraint(equalTo: lines.trailingAnchor, constant: Self.gap),
            controls.trailingAnchor.constraint(equalTo: trailingAnchor),
            controls.centerYAnchor.constraint(equalTo: centerYAnchor),
            toggle.widthAnchor.constraint(equalToConstant: Self.toggleWidth),
            topAnchor.constraint(equalTo: placeholder.topAnchor),
            bottomAnchor.constraint(equalTo: placeholder.bottomAnchor),
        ])
    }

    func show(_ track: WidgetGrid.Track) {
        title.stringValue = track.title
        artist.stringValue = track.artist
        toggle.image = NSImage(
            systemSymbolName: track.isPlaying ? "pause" : "play",
            accessibilityDescription: nil)
        guard track.artwork != artwork || art.image == nil else { return }
        artwork = track.artwork
        if let image = track.artwork.flatMap(NSImage.init(data:)) {
            art.image = image
            art.imageScaling = .scaleProportionallyUpOrDown
            art.symbolConfiguration = nil
        } else {
            art.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
            art.imageScaling = .scaleNone
            art.symbolConfiguration = .init(pointSize: Self.noteSize, weight: .regular)
            art.contentTintColor = .secondaryLabelColor
        }
    }
}
