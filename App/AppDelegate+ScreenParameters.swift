import AppKit

extension AppDelegate {
    func applicationDidChangeScreenParameters(_: Notification) {
        settings?.refresh()
    }
}
