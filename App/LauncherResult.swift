import AppCore
import Foundation
import GlassUI
import SearchKit

@MainActor
enum LauncherResult {
    case app(AppIndex.App)
    case command(Command)
    case pane(SettingsPane)

    var id: String {
        switch self {
        case .app(let app): app.url.path
        case .command(let command): command.id
        case .pane(let pane): pane.id
        }
    }

    var keys: [String] {
        switch self {
        case .app(let app): app.keys
        case .command(let command): [command.name] + command.keywords
        case .pane(let pane): [pane.name]
        }
    }

    static func sections(
        for query: String, apps: AppIndex, commands: [Command], usage: Usage
    ) -> [ResultList.Section] {
        let typed = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let candidates =
            typed
            ? apps.apps.map(Self.app) + SettingsPane.all.map(Self.pane) + commands.map(Self.command)
            : commands.map(Self.command)
        let now = Date.now
        let ranked = Fuzzy.rank(
            candidates, by: query, bonus: { usage.bonus(for: $0.id, at: now) }, keys: \.keys)
        return [
            ResultList.Section(
                title: typed ? "Results" : "Commands", items: ranked.map { $0.item(icons: apps) })
        ]
    }

    private func item(icons apps: AppIndex) -> ResultList.Item {
        switch self {
        case .app(let app):
            ResultList.Item(
                id: id, title: app.name, subtitle: app.folder, kind: "Application", symbol: "",
                icon: apps.icon(for: app))

        case .command(let command):
            ResultList.Item(
                id: id, title: command.name, subtitle: "", kind: "Command", symbol: command.icon)

        case .pane(let pane):
            pane.item
        }
    }
}
