public import AppKit

public enum AppHotKeyMode {
    public static let toggle = "Toggle"
    public static let summary = ": launch if closed → bring to front → hide if already in front."
    static let quickPeek = "Quick Peek"

    public static func menu() -> NSPopUpButton {
        let menu = NSPopUpButton(frame: .zero, pullsDown: false)
        menu.autoenablesItems = false
        menu.addItems(withTitles: [toggle, quickPeek])
        menu.lastItem?.isEnabled = false
        return menu
    }
}
