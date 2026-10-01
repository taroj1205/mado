import AppKit
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let signposter: OSSignposter
    private let launch: OSSignpostIntervalState
    private var statusItem: NSStatusItem?

    init(signposter: OSSignposter, launch: OSSignpostIntervalState) {
        self.signposter = signposter
        self.launch = launch
    }

    func applicationDidFinishLaunching(_: Notification) {
        statusItem = makeStatusItem()
        signposter.endInterval("launch", launch)
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        statusItem?.isVisible = true
        return true
    }

    private func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.behavior = .removalAllowed
        item.isVisible = true
        item.button?.image = NSImage(
            systemSymbolName: "macwindow", accessibilityDescription: "Mado")

        let menu = NSMenu()
        menu.addItem(withTitle: "Open Mado", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: nil, keyEquivalent: ",")
        menu.addItem(.separator())
        let hide = menu.addItem(
            withTitle: "Hide Menu Bar Icon", action: #selector(hideStatusItem), keyEquivalent: "")
        hide.target = self
        hide.toolTip = "Open Mado again to show the icon."
        menu.addItem(
            withTitle: "Quit Mado", action: #selector(NSApplication.terminate), keyEquivalent: "q")
        item.menu = menu
        return item
    }

    @objc
    private func hideStatusItem() {
        statusItem?.isVisible = false
    }
}
