import AppKit

final class SettingsWindow: NSWindow {
    private static let escape = "\u{1B}"

    var onEscape: (() -> Bool)?

    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == Self.escape, onEscape?() == true {
            return
        }
        super.keyDown(with: event)
    }
}
