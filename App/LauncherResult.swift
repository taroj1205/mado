import AppCore
import AppKit
import GlassUI
import SearchKit

@MainActor
enum LauncherResult {
    case app(AppIndex.App)
    case command(Command)
    case pane(SettingsPane)

    private static let openApp = "Open Application"
    private static let fileLimit = 20

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
        case .pane(let pane): pane.keys
        }
    }

    static func sections(
        for query: String, apps: AppIndex, files: FileIndex, commands: [Command], usage: Usage
    ) -> [ResultList.Section] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let typed = !trimmed.isEmpty
        let candidates =
            typed
            ? apps.apps.map(Self.app) + SettingsPane.all.map(Self.pane) + commands.map(Self.command)
            : commands.map(Self.command)
        let now = Date.now
        let ranked = Fuzzy.rank(
            candidates, by: query, bonus: { usage.bonus(for: $0.id, at: now) }, keys: \.keys)
        let fileBonus = { (file: FileIndex.File) in usage.bonus(for: file.url.path, at: now) }
        let found =
            typed ? Fuzzy.rank(files.files, by: query, bonus: fileBonus) { [$0.key] } : []
        if typed, ranked.isEmpty, found.isEmpty { return [Fallback.section(for: trimmed)] }
        return [
            ResultList.Section(
                title: typed ? "Results" : "Commands", items: ranked.map { $0.item(icons: apps) }),
            ResultList.Section(
                title: "Files", items: found.prefix(fileLimit).map { item(for: $0, at: now) }),
        ]
    }

    static func actions(
        for id: String, query: String, apps: AppIndex, files: FileIndex, commands: [Command]
    ) -> [CommandAction] {
        if let file = files.files.first(where: { $0.url.path == id }) {
            return [
                CommandAction(id: "open", title: "Open") {
                    _ = try await NSWorkspace.shared.open(
                        file.url, configuration: NSWorkspace.OpenConfiguration())
                },
                CommandAction(id: "reveal", title: "Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([file.url])
                },
            ]
        }
        if let pane = SettingsPane.all.first(where: { $0.id == id }) { return [pane.open] }
        if let fallback = Fallback.all.first(where: { $0.item.id == id }) {
            return [fallback.action(for: query.trimmingCharacters(in: .whitespacesAndNewlines))]
        }
        guard let app = apps.apps.first(where: { $0.url.path == id }) else {
            return commands.first { $0.id == id }?.actions ?? []
        }
        return [
            CommandAction(id: "open", title: Self.openApp) {
                _ = try await NSWorkspace.shared.openApplication(
                    at: app.url, configuration: NSWorkspace.OpenConfiguration())
            }
        ]
    }

    private static func item(for file: FileIndex.File, at now: Date) -> ResultList.Item {
        ResultList.Item(
            id: file.url.path, title: file.name, subtitle: file.folder,
            kind: FileIndex.kind(of: file, at: now), symbol: "", action: "Open",
            icon: NSWorkspace.shared.icon(forFile: file.url.path), file: file.url)
    }

    private func item(icons apps: AppIndex) -> ResultList.Item {
        switch self {
        case .app(let app):
            ResultList.Item(
                id: id, title: app.name, subtitle: app.folder, kind: "Application", symbol: "",
                action: Self.openApp, icon: apps.icon(for: app))

        case .command(let command):
            ResultList.Item(
                id: id, title: command.name, subtitle: "", kind: "Command", symbol: command.icon,
                action: "Run Command")

        case .pane(let pane):
            pane.item
        }
    }
}
