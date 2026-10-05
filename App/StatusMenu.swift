import AppKit

@MainActor
enum StatusMenu {
    private static let iconSize: CGFloat = 16
    private static let artboard: CGFloat = 18
    private static let edge: CGFloat = 2.75
    private static let radius: CGFloat = 3
    private static let lineWidth: CGFloat = 1.5
    private static let gapInset: CGFloat = 2
    private static let gapWidth: CGFloat = 4
    private static let slashInset: CGFloat = 2.6
    private static let half: CGFloat = 0.5

    static func makeItem(
        target: AnyObject, open: Selector, settings: Selector, pauseKeys: Selector, hide: Selector
    ) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "Mado"
        item.behavior = .removalAllowed

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
        if #available(macOS 26, *) {
            hideItem.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: nil)
        }
        hideItem.toolTip = "Open Mado again to show the icon."
        menu.addItem(
            withTitle: "Quit Mado", action: #selector(NSApplication.terminate), keyEquivalent: "q")
        item.menu = menu
        return item
    }

    static func icon(keysPaused: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: iconSize, height: iconSize), flipped: true) { _ in
            let scale = iconSize / artboard
            NSGraphicsContext.current?.cgContext.scaleBy(x: scale, y: scale)
            NSColor.black.set()
            drawPane()
            if keysPaused { drawSlash() }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = keysPaused ? "Mado, keyboard features paused" : "Mado"
        return image
    }

    private static func drawPane() {
        let far = artboard - edge
        let mid = artboard * half
        let outline = NSBezierPath(
            roundedRect: NSRect(x: edge, y: edge, width: far - edge, height: far - edge),
            xRadius: radius, yRadius: radius)
        outline.move(to: NSPoint(x: mid, y: edge))
        outline.line(to: NSPoint(x: mid, y: far))
        outline.move(to: NSPoint(x: edge, y: mid))
        outline.line(to: NSPoint(x: far, y: mid))
        outline.lineWidth = lineWidth
        outline.lineCapStyle = .round
        outline.lineJoinStyle = .round
        outline.stroke()

        let lit = NSBezierPath()
        lit.move(to: NSPoint(x: edge, y: mid))
        lit.appendArc(
            from: NSPoint(x: edge, y: edge), to: NSPoint(x: mid, y: edge), radius: radius)
        lit.line(to: NSPoint(x: mid, y: edge))
        lit.line(to: NSPoint(x: mid, y: mid))
        lit.close()
        lit.fill()
    }

    private static func slash(inset: CGFloat, width: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: inset, y: artboard - inset))
        path.line(to: NSPoint(x: artboard - inset, y: inset))
        path.lineWidth = width
        path.lineCapStyle = .round
        return path
    }

    private static func drawSlash() {
        NSGraphicsContext.current?.compositingOperation = .clear
        slash(inset: gapInset, width: gapWidth).stroke()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
        slash(inset: slashInset, width: lineWidth).stroke()
    }
}
