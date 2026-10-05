import AppKit

extension AppDelegate {
    func settingsWindow() -> SettingsWindowController {
        if let settings { return settings }
        let controller = SettingsWindowController(
            modules: modules, hotKeys: hotKeys, rates: rates, items: editor,
            snippets: snippets, statusItem: statusItem, menuBarAgenda: menuBar.agenda,
            addWidgets: { [weak self] in self?.editWidgetsInLauncher() },
            lyricsChanged: { [weak self] in self?.applyLyricsSettings() })
        settings = controller
        return controller
    }

    @objc
    func showSettings() {
        settingsWindow().showWindow(nil)
    }
}
