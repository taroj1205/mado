import AppCore
import SearchKit
import WindowKit

extension LauncherResult {
    struct Sources {
        let apps: AppIndex
        let files: FileIndex
        let commands: [Command]
        let quicklinks: [Quicklink]
        let items: ItemSettings
        let rates: ExchangeRates?
        let answers: AnswerSettings
        let settingIDs: @MainActor (String) -> [String]
        let openSetting: SettingsLink.Opening
    }

    private static let settingLimit = 8

    static func hotKeyAction(for id: String, in sources: Sources) -> CommandAction? {
        if let app = AppToggle.app(for: id) {
            return sources.items[id].quickPeek
                ? CommandAction(id: "peek", title: "Quick Peek") { try await AppToggle.peek(app) }
                : CommandAction(id: "toggle", title: "Toggle") { try await AppToggle.toggle(app) }
        }
        return result(for: id, in: sources)?.actions.first
    }

    static func settingResults(for query: String, in sources: Sources) -> [Self] {
        guard !query.isEmpty else { return [] }
        return sources.settingIDs(query).prefix(settingLimit).compactMap { id in
            SettingsLink(id: id, opening: sources.openSetting).map(Self.setting)
        }
    }
}
