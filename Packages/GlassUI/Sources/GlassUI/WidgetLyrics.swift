import AppKit

final class WidgetLyrics: NSView {
    struct Compact {
        let kept: [Int]
        let current: Int?
        let gap: Double?
    }

    private static let pitch: CGFloat = 30
    private static let currentSize: CGFloat = 16
    private static let restSize: CGFloat = 12.5
    private static let coverSize: CGFloat = 20
    private static let coverRadius: CGFloat = 5
    private static let headerSize: CGFloat = 11.5
    private static let headerGap: CGFloat = 8
    private static let columnGap: CGFloat = 4
    private static let headlineSize: CGFloat = 13
    private static let detailSize: CGFloat = 12
    private static let messageGap: CGFloat = 3
    private static let inset: CGFloat = 6

    private let cover = NSImageView()
    private let heading = NSTextField(labelWithString: "")
    private let equalizer = WidgetEqualizer()
    private let column = LyricsColumn(
        look: .init(pitch: pitch, size: currentSize, rest: restSize))
    private let headline = NSTextField(labelWithString: "")
    private let detail = NSTextField(labelWithString: "")
    private let message = NSStackView()
    private(set) var tint: NSColor?
    private var shown: WidgetGrid.Verse?
    private var originals: [Int] = []

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        cover.wantsLayer = true
        cover.layer?.cornerRadius = Self.coverRadius
        cover.layer?.cornerCurve = .continuous
        cover.layer?.masksToBounds = true
        cover.imageScaling = .scaleAxesIndependently
        heading.font = .systemFont(ofSize: Self.headerSize)
        heading.textColor = .secondaryLabelColor
        heading.lineBreakMode = .byTruncatingTail
        heading.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        headline.font = .systemFont(ofSize: Self.headlineSize, weight: .semibold)
        detail.font = .systemFont(ofSize: Self.detailSize)
        detail.textColor = .secondaryLabelColor
        for label in [headline, detail] {
            label.alignment = .center
            label.lineBreakMode = .byTruncatingTail
        }
        message.orientation = .vertical
        message.spacing = Self.messageGap
        [headline, detail].forEach(message.addArrangedSubview)
        layOut()
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func message(
        for status: WidgetGrid.LyricsStatus
    ) -> (headline: String, detail: String)? {
        switch status {
        case .synced, .plain: nil
        case .instrumental: ("Instrumental", "No words in this one")
        case .missing: ("No lyrics found", "")
        case .loading: ("Looking up lyrics…", "")
        case .off: ("Lyrics lookup is off", "Turn it on in Settings › Media")
        }
    }

    static func compact(_ lines: [String], current: Int?) -> Compact {
        let kept = lines.indices.filter { !lines[$0].isEmpty }
        guard let current else { return Compact(kept: kept, current: nil, gap: nil) }
        if let position = kept.firstIndex(of: current) {
            return Compact(kept: kept, current: position, gap: nil)
        }
        let before = kept.lastIndex { $0 < current }
        return Compact(
            kept: kept, current: before ?? (kept.isEmpty ? nil : 0), gap: before == nil ? 0 : 1)
    }

    private func layOut() {
        let header = NSStackView(views: [cover, heading, equalizer])
        header.spacing = Self.headerGap
        for view in [header, column, message] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            cover.widthAnchor.constraint(equalToConstant: Self.coverSize),
            cover.heightAnchor.constraint(equalToConstant: Self.coverSize),
            header.leadingAnchor.constraint(equalTo: leadingAnchor),
            header.trailingAnchor.constraint(equalTo: trailingAnchor),
            header.topAnchor.constraint(equalTo: topAnchor),
            column.leadingAnchor.constraint(equalTo: leadingAnchor),
            column.trailingAnchor.constraint(equalTo: trailingAnchor),
            column.topAnchor.constraint(equalTo: header.bottomAnchor, constant: Self.columnGap),
            column.bottomAnchor.constraint(equalTo: bottomAnchor),
            message.centerXAnchor.constraint(equalTo: centerXAnchor),
            message.centerYAnchor.constraint(equalTo: column.centerYAnchor),
            message.leadingAnchor.constraint(
                greaterThanOrEqualTo: leadingAnchor, constant: Self.inset),
            message.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor, constant: -Self.inset),
        ])
    }

    func line(at point: NSPoint) -> Int? {
        column.line(at: column.convert(point, from: self)).map { originals[$0] }
    }

    func show(_ verse: WidgetGrid.Verse) {
        heading.stringValue =
            verse.artist.isEmpty ? verse.title : "\(verse.title) · \(verse.artist)"
        equalizer.isActive = verse.isPlaying
        equalizer.alphaValue = verse.isPlaying ? 1 : 0
        if shown?.artwork != verse.artwork {
            let image = verse.artwork.flatMap(NSImage.init(data:))
            cover.image = image
            cover.isHidden = image == nil
            tint = image.flatMap(ArtworkTint.of)
        }
        let text = Self.message(for: verse.status)
        message.isHidden = text == nil
        column.isHidden = text != nil
        headline.stringValue = text?.headline ?? ""
        detail.stringValue = text?.detail ?? ""
        detail.isHidden = text?.detail.isEmpty ?? true
        if text == nil {
            let compact = Self.compact(
                verse.lines, current: verse.status == .synced ? verse.current : nil)
            originals = compact.kept
            column.show(
                compact.kept.map { verse.lines[$0] }, current: compact.current,
                progress: compact.gap ?? verse.progress,
                remaining: compact.gap == nil ? verse.remaining : nil, playing: verse.isPlaying)
        }
        shown = verse
    }
}
