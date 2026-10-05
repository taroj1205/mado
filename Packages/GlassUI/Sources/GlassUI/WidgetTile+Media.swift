import AppKit

extension WidgetTile {
    func showTrack(_ shows: Bool) {
        track.isHidden = !shows
        if shows {
            NSLayoutConstraint.activate(trackPlacement)
        } else {
            NSLayoutConstraint.deactivate(trackPlacement)
        }
    }

    func showVerse(_ shows: Bool) {
        verse.isHidden = !shows
        if shows {
            NSLayoutConstraint.activate(versePlacement)
        } else {
            NSLayoutConstraint.deactivate(versePlacement)
        }
    }

    func skip(_ name: String, _ skip: WidgetGrid.Skip) -> NSAccessibilityCustomAction {
        NSAccessibilityCustomAction(name: name) { [weak self] in
            self?.onSkip?(skip)
            return true
        }
    }

    func lyricLine(at event: NSEvent) -> Int? {
        verse.isHidden ? nil : verse.line(at: verse.convert(event.locationInWindow, from: nil))
    }
}
