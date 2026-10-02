import AppKit

extension AppDelegate {
    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        statusItem?.isVisible = true
        return true
    }

    @objc
    func hideStatusItem() {
        statusItem?.isVisible = false
    }
}
