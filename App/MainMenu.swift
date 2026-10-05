import AppKit

@MainActor
enum MainMenu {
    static func make(target: AnyObject, settings: Selector) -> NSMenu {
        let app = NSMenu()
        let settingsItem = app.addItem(
            withTitle: "Settings…", action: settings, keyEquivalent: ",")
        settingsItem.target = target
        app.addItem(.separator())
        app.addItem(
            withTitle: "Hide Mado", action: #selector(NSApplication.hide), keyEquivalent: "h")
        app.addItem(
            withTitle: "Quit Mado", action: #selector(NSApplication.terminate), keyEquivalent: "q")
        let window = NSMenu(title: "Window")
        window.addItem(
            withTitle: "Close", action: #selector(NSWindow.performClose), keyEquivalent: "w")
        window.addItem(
            withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize),
            keyEquivalent: "m")
        NSApp.windowsMenu = window
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste), keyEquivalent: "v")
        edit.addItem(
            withTitle: "Paste and Match Style", action: #selector(NSTextView.pasteAsPlainText),
            keyEquivalent: "v"
        ).keyEquivalentModifierMask = [.command, .option, .shift]
        edit.addItem(
            withTitle: "Select All", action: #selector(NSText.selectAll), keyEquivalent: "a")
        edit.addItem(.separator())
        edit.addItem(
            withTitle: "Find…", action: #selector(SettingsWindowController.focusSearch),
            keyEquivalent: "f")

        let menu = NSMenu()
        for submenu in [app, edit, window] {
            menu.addItem(withTitle: submenu.title, action: nil, keyEquivalent: "").submenu = submenu
        }
        return menu
    }
}
