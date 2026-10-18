import AppKit
import SearchKit

extension AppDelegate {
    func makeSettingsContext() -> SettingsPage.Context {
        let recorder = HotKeyPopover(items: editor)
        let ignoredApps = AppListSettings.ignoredApps(modules: modules)
        let withoutExpansion = AppListSettings.withoutExpansion(modules: modules)
        let fileFolders = FolderListSettings(modules: modules) { [weak self] folders in
            self?.files.use(folders)
        }
        let inputKeys = InputSourceKeys(modules: modules, recorder: recorder)
        let inputDefaults = AppInputDefaults(modules: modules)
        let remaps = RemapsSettings(modules: modules, recorder: recorder)
        let enterGuard = EnterGuardPage(modules: modules)
        let dictationLanguages = DictationLanguageSettings(modules: modules)
        let speechModels = SpeechModelSettings(modules: modules)
        return SettingsPage.Context(
            modules: modules, hotKeys: hotKeys, rates: rates, recorder: recorder,
            apps: AppHotKeys(items: editor, recorder: recorder),
            radial: RadialMenuSettings(modules: modules),
            clipboardHistory: ClipboardHistorySettings(modules: modules), ignoredApps: ignoredApps,
            withoutExpansion: withoutExpansion, fileFolders: fileFolders, inputKeys: inputKeys,
            inputDefaults: inputDefaults, remaps: remaps, enterGuard: enterGuard,
            addWidgets: { [weak self] in self?.editWidgetsInLauncher() },
            lyricsChanged: { [weak self] in self?.applyLyricsSettings() },
            dictationLanguages: dictationLanguages, speechModels: speechModels,
            colourKeys: ColourPickerKeysPage(modules: modules), statusItem: statusItem,
            menuBarAgenda: menuBar.agenda)
    }

    func finder() -> SettingsFinder {
        if let settingsFinder { return settingsFinder }
        let made = SettingsFinder(context: makeSettingsContext()) { [weak self] in
            self?.settings?.shown ?? []
        }
        settingsFinder = made
        return made
    }

    func settingsWindow() -> SettingsWindowController {
        if let settings { return settings }
        let controller = SettingsWindowController(finder: finder(), snippets: snippets)
        settings = controller
        return controller
    }

    func reloadSettings() {
        settingsFinder?.invalidate()
        settings?.reload()
    }

    @objc
    func showSettings() {
        settingsWindow().showWindow(nil)
    }
}
