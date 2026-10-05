import AppKit

extension LauncherView {
    static let pinTitle = "Pin to screen"
    static let unpinTitle = "Unpin"
    private static let checkSymbol = "checkmark"
    private static let checkSize: CGFloat = 16

    private static func check(_ shown: Bool) -> NSImage {
        let size = NSSize(width: checkSize, height: checkSize)
        guard shown,
            let mark = NSImage(systemSymbolName: checkSymbol, accessibilityDescription: "Pinned")
        else { return NSImage(size: size) }
        return mark
    }

    func pinAction(for widget: WidgetGrid.Widget) -> Action? {
        guard widget.isMedia, let onPinLyrics else { return nil }
        let current = pinnedLyrics
        var action = Action(Self.pinTitle) {
            let unpin =
                current == nil
                ? []
                : [ActionChoice(Self.unpinTitle, icon: Self.check(false)) { onPinLyrics(nil) }]
            return LyricsPin.allCases.map { pin in
                ActionChoice(pin.title, icon: Self.check(pin == current)) { onPinLyrics(pin) }
            } + unpin
        }
        action.detail = current?.title
        return action
    }

    func presentPin(for widget: WidgetGrid.Widget) {
        guard let pin = pinAction(for: widget) else { return }
        present([pin], for: widget.name) { [weak self] _ in self?.closeActions() }
        actionPanel?.choose(0)
    }

    func pinOffPanel() {
        onPinLyrics?(.island)
    }
}
