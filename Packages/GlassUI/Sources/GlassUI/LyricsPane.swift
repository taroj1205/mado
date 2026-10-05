import AppKit

final class LyricsPane: NSView {
    static let syncedBadge = "Synced · LRCLIB"
    static let plainBadge = "Not synced"
    static let nothingPlaying = "Nothing is playing"
    private static let caption = "LYRICS"
    private static let groupLabel = "Lyrics"
    private static let top: CGFloat = 18
    private static let side: CGFloat = 22
    private static let bottom: CGFloat = 8
    private static let columnGap: CGFloat = 26
    private static let headerHeight: CGFloat = 24
    private static let captionSize: CGFloat = 11
    private static let captionTracking: CGFloat = 0.4
    private static let badgeHeight: CGFloat = 20
    private static let badgeRadius: CGFloat = 10
    private static let badgeInset: CGFloat = 18
    private static let linesGap: CGFloat = 6
    private static let emptySize: CGFloat = 13

    let track = LyricsPaneTrack()
    let caption = NSTextField(labelWithString: "")
    let badge = Keycap("", radius: badgeRadius, size: badgeHeight)
    let lines = LyricsPaneLines()
    let note = LyricsPaneNote()
    let hints = LyricsPaneHints()
    let empty = NSTextField(labelWithString: nothingPlaying)
    let body = NSView()
    var pasteboard = NSPasteboard.general
    var onSeek: ((Int) -> Void)?
    private(set) var verse: WidgetGrid.Verse?

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isHidden = true
        caption.attributedStringValue = NSAttributedString(
            string: Self.caption,
            attributes: [
                .font: NSFont.systemFont(ofSize: Self.captionSize, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor, .kern: Self.captionTracking,
            ])
        empty.font = .systemFont(ofSize: Self.emptySize)
        empty.textColor = .secondaryLabelColor
        lines.onSeek = { [weak self] line in self?.seek(to: line) }
        layOut()
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(Self.groupLabel)
        show(nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func show(_ next: WidgetGrid.Verse?) {
        verse = next
        empty.isHidden = next != nil
        body.isHidden = next == nil
        guard let next else { return }
        track.show(next)
        let synced = next.status == .synced
        let hasLines = synced || next.status == .plain
        lines.isHidden = !hasLines
        badge.isHidden = !hasLines
        badge.name.stringValue = synced ? Self.syncedBadge : Self.plainBadge
        note.show(next.status)
        hints.show(LyricsPaneHints.hints(for: next.status))
        guard hasLines else { return }
        lines.show(next)
    }

    func browse(by step: Int) {
        guard !lines.isHidden else { return }
        lines.browse(by: step)
    }

    func playFocused() {
        guard !lines.isHidden, let line = lines.focus else { return }
        seek(to: line)
    }

    @discardableResult
    func follow() -> Bool {
        lines.follow()
    }

    @discardableResult
    func copyLine() -> Bool {
        guard !lines.isHidden, let text = lines.copied else { return false }
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    private func seek(to line: Int) {
        lines.follow()
        onSeek?(line)
    }

    private func layOut() {
        for view in [track, caption, badge, lines, note, hints] {
            view.translatesAutoresizingMaskIntoConstraints = false
            body.addSubview(view)
        }
        for view in [body, empty] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            body.leadingAnchor.constraint(equalTo: leadingAnchor),
            body.trailingAnchor.constraint(equalTo: trailingAnchor),
            body.topAnchor.constraint(equalTo: topAnchor),
            body.bottomAnchor.constraint(equalTo: bottomAnchor),
            empty.centerXAnchor.constraint(equalTo: centerXAnchor),
            empty.centerYAnchor.constraint(equalTo: centerYAnchor),
            track.topAnchor.constraint(equalTo: body.topAnchor, constant: Self.top),
            track.leadingAnchor.constraint(equalTo: body.leadingAnchor, constant: Self.side),
        ])
        placeColumn()
    }

    private func placeColumn() {
        let column = NSLayoutGuide()
        body.addLayoutGuide(column)
        let spans = [lines, note, hints].flatMap { view in
            [
                view.leadingAnchor.constraint(equalTo: column.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            ]
        }
        NSLayoutConstraint.activate(
            spans + [
                column.leadingAnchor.constraint(
                    equalTo: track.trailingAnchor, constant: Self.columnGap),
                column.trailingAnchor.constraint(
                    equalTo: body.trailingAnchor, constant: -Self.side),
                column.topAnchor.constraint(equalTo: body.topAnchor, constant: Self.top),
                column.heightAnchor.constraint(equalToConstant: Self.headerHeight),
                caption.leadingAnchor.constraint(equalTo: column.leadingAnchor),
                caption.centerYAnchor.constraint(equalTo: column.centerYAnchor),
                badge.trailingAnchor.constraint(equalTo: column.trailingAnchor),
                badge.centerYAnchor.constraint(equalTo: column.centerYAnchor),
                badge.widthAnchor.constraint(
                    equalTo: badge.name.widthAnchor, constant: Self.badgeInset),
                lines.topAnchor.constraint(equalTo: column.bottomAnchor, constant: Self.linesGap),
                lines.bottomAnchor.constraint(equalTo: hints.topAnchor),
                note.topAnchor.constraint(equalTo: lines.topAnchor),
                note.bottomAnchor.constraint(equalTo: lines.bottomAnchor),
                hints.bottomAnchor.constraint(equalTo: body.bottomAnchor, constant: -Self.bottom),
            ])
    }
}
