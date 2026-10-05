import AppKit

extension WidgetTile {
    func verseConstraints() -> [NSLayoutConstraint] {
        [
            verse.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontal),
            verse.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontal),
            verse.topAnchor.constraint(equalTo: topAnchor, constant: Self.vertical),
            verse.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.vertical),
        ]
    }

    func showVerse(_ shows: Bool) {
        verse.isHidden = !shows
        if shows {
            NSLayoutConstraint.activate(versePlacement)
        } else {
            NSLayoutConstraint.deactivate(versePlacement)
        }
    }

    func lyricLine(at event: NSEvent) -> Int? {
        verse.isHidden ? nil : verse.line(at: verse.convert(event.locationInWindow, from: nil))
    }
}
