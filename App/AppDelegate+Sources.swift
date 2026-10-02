import AppCore
import SearchKit

extension AppDelegate {
    var sources: LauncherResult.Sources {
        LauncherResult.Sources(
            apps: apps, files: files, commands: modules?.commands.all ?? [], rates: rates.rates,
            answers: AnswerSettings.load(from: modules))
    }

    func ratesChanged() {
        searchAgain()
        settings?.refresh()
    }
}
