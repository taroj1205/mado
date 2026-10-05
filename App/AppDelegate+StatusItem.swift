import AppCore
import AppKit
import SearchKit

extension AppDelegate: NSMenuItemValidation {
    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        statusItem?.isVisible = true
        settings?.refresh()
        return true
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        guard item.action == #selector(toggleKeysPaused) else { return true }
        item.state = modules?.keysPaused == true ? .on : .off
        return modules != nil
    }

    func makeStatusItem(settings: Selector) -> NSStatusItem {
        modules?.onKeysPausedChange = { [weak self] in self?.keysPausedChanged() }
        menuBar.agenda.openSettings = { [weak self] in
            self?.settingsWindow().open(.init(page: "Notes", tab: nil), entry: nil)
        }
        menuBar.timer.openLauncher = { [weak self] in self?.openTimerSearch() }
        let item = StatusMenu.makeItem(
            target: self, open: #selector(showLauncher), settings: settings,
            pauseKeys: #selector(toggleKeysPaused), hide: #selector(hideStatusItem))
        item.button?.image = StatusMenu.icon(keysPaused: modules?.keysPaused == true)
        return item
    }

    @objc
    func hideStatusItem() {
        statusItem?.isVisible = false
        settings?.refresh()
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
