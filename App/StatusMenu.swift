import AppKit

@MainActor
enum StatusMenu {
    static func makeItem(
        target: AnyObject, open: Selector, settings: Selector, hide: Selector
    ) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.behavior = .removalAllowed
        item.isVisible = true
        item.button?.image = NSImage(
            systemSymbolName: "macwindow", accessibilityDescription: "Mado")

        let menu = NSMenu()
        let openItem = menu.addItem(
            withTitle: "Open Mado", action: open, keyEquivalent: "")
        openItem.target = target
        let settingsItem = menu.addItem(
            withTitle: "Settings…", action: settings, keyEquivalent: ",")
        settingsItem.target = target
        menu.addItem(.separator())
        let hideItem = menu.addItem(
            withTitle: "Hide Menu Bar Icon", action: hide, keyEquivalent: "")
        hideItem.target = target
        hideItem.toolTip = "Open Mado again to show the icon."
        menu.addItem(
            withTitle: "Quit Mado", action: #selector(NSApplication.terminate), keyEquivalent: "q")
        item.menu = menu
        return item
    }
}
