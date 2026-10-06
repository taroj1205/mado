import AppKit

extension LauncherView {
    public static let lyricsQuery = "lyrics"

    public var showsLyrics: Bool { !lyricsPane.isHidden }

    public var onPlayPause: (() -> Void)? {
        get { lyricsPane.track.onPlayPause }
        set { lyricsPane.track.onPlayPause = newValue }
    }

    public var onLyricsSettings: (() -> Void)? {
        get { lyricsPane.note.onSettings }
        set { lyricsPane.note.onSettings = newValue }
    }

    public func openLyrics() {
        replaceQuery(with: Self.lyricsQuery)
    }

    public func showLyrics(_ shown: Bool) {
        let changed = shown != showsLyrics
        lyricsPane.isHidden = !shown
        results.isHidden = shown || showsGrid
        if !shown {
            lyricsPane.follow()
        }
        showAction(of: selectedItem)
        if changed {
            onFit?()
        }
    }

    func placeLyrics(below separator: NSView) {
        NSLayoutConstraint.activate([
            lyricsPane.leadingAnchor.constraint(equalTo: leadingAnchor),
            lyricsPane.trailingAnchor.constraint(equalTo: trailingAnchor),
            lyricsPane.topAnchor.constraint(equalTo: separator.bottomAnchor),
            lyricsPane.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        lyricsPane.onSeek = { [weak self] line in self?.onSeek?(line) }
        lyricsPane.track.onSkip = { [weak self] skip in self?.onSkip?(skip) }
    }

    func showVerse(among widgets: [WidgetGrid.Widget]) {
        lyricsPane.show(widgets.lazy.compactMap(\.verse).first)
    }

    func lyricsCommand(_ selector: Selector, in textView: NSTextView) -> Bool {
        switch selector {
        case #selector(NSResponder.moveUp): lyricsPane.browse(by: -1)
        case #selector(NSResponder.moveDown): lyricsPane.browse(by: 1)

        case #selector(NSResponder.insertNewline) where !textView.hasMarkedText():
            lyricsPane.playFocused()

        case #selector(NSResponder.cancelOperation): return lyricsPane.follow()

        case #selector(NSResponder.moveUpAndModifySelection),
            #selector(NSResponder.moveDownAndModifySelection),
            #selector(NSResponder.insertNewlineIgnoringFieldEditor):
            break

        default: return false
        }
        return true
    }

    func lyricsKeyEquivalent(_ event: NSEvent) -> Bool {
        guard showsLyrics, event.modifierFlags.intersection(Self.modifierKeys) == .command,
            event.charactersIgnoringModifiers == "c",
            (field.currentEditor() as? NSTextView)?.hasMarkedText() != true
        else { return false }
        return lyricsPane.copyLine()
    }
}
