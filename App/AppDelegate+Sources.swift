import AppCore
import SearchKit

extension AppDelegate {
    var sources: LauncherResult.Sources {
        LauncherResult.Sources(
            apps: apps, files: files, commands: modules?.commands.all ?? [],
            quicklinks: editor.quicklinks.links, items: editor.settings, rates: rates.rates,
            answers: AnswerSettings.load(from: modules),
            settingIDs: { [weak self] in self?.settingsWindow().finder.ids(for: $0) ?? [] },
            openSetting: { [weak self] place, entry in
                self?.settingsWindow().open(place, entry: entry)
            })
    }

    func ratesChanged() {
        searchAgain()
        settings?.refresh()
    }
}
