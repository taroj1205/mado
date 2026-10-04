import AppCore
import AppKit

extension AppDelegate: NSMenuItemValidation {
    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        statusItem?.isVisible = true
        return true
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        guard item.action == #selector(toggleKeysPaused) else { return true }
        item.state = modules?.keysPaused == true ? .on : .off
        return modules != nil
    }

    func makeStatusItem(settings: Selector) -> NSStatusItem {
        modules?.onKeysPausedChange = { [weak self] in self?.keysPausedChanged() }
        let item = StatusMenu.makeItem(
            target: self, open: #selector(showLauncher), settings: settings,
            pauseKeys: #selector(toggleKeysPaused), hide: #selector(hideStatusItem))
        item.button?.image = StatusMenu.icon(keysPaused: modules?.keysPaused == true)
        return item
    }

    @objc
    func hideStatusItem() {
        statusItem?.isVisible = false
    }

    @objc
    func toggleKeysPaused() {
        guard let modules else { return }
        modules.setKeysPaused(!modules.keysPaused)
    }

    func keysPausedChanged() {
        statusItem?.button?.image = StatusMenu.icon(keysPaused: modules?.keysPaused == true)
        editor.refreshHotKeys()
    }
}
