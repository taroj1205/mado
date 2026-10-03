import AppKit

@MainActor
enum StatusMenu {
    private static let slashWidth: CGFloat = 1.5

    static func makeItem(
        target: AnyObject, open: Selector, settings: Selector, pauseKeys: Selector, hide: Selector
    ) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.behavior = .removalAllowed
        item.isVisible = true
        item.button?.image = icon(keysPaused: false)

        let menu = NSMenu()
        let openItem = menu.addItem(
            withTitle: "Open Mado", action: open, keyEquivalent: "")
        openItem.target = target
        let settingsItem = menu.addItem(
            withTitle: "Settings…", action: settings, keyEquivalent: ",")
        settingsItem.target = target
        menu.addItem(.separator())
        let pauseItem = menu.addItem(
            withTitle: "Pause Keyboard Features", action: pauseKeys, keyEquivalent: "")
        pauseItem.target = target
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

    static func icon(keysPaused: Bool) -> NSImage? {
        let name = keysPaused ? "Mado, keyboard features paused" : "Mado"
        guard let symbol = NSImage(systemSymbolName: "macwindow", accessibilityDescription: name)
        else { return nil }
        guard keysPaused else { return symbol }
        let slashed = NSImage(size: symbol.size, flipped: false) { rect in
            symbol.draw(in: rect)
            let slash = NSBezierPath()
            slash.move(to: NSPoint(x: rect.minX, y: rect.minY))
            slash.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
            slash.lineWidth = slashWidth
            slash.lineCapStyle = .round
            NSColor.black.setStroke()
            slash.stroke()
            return true
        }
        slashed.isTemplate = true
        slashed.accessibilityDescription = name
        return slashed
    }
}
