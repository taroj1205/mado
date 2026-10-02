import AppCore
import AppKit
import GlassUI
import SearchKit

@MainActor
enum LauncherResult {
    case app(AppIndex.App)
    case command(Command)
    case file(FileIndex.File)
    case pane(SettingsPane)

    struct Sources {
        let apps: AppIndex
        let files: FileIndex
        let commands: [Command]
        let rates: ExchangeRates?
    }

    private static let openApp = "Open Application"
    private static let answerID = "calculator"
    private static let fileLimit = 20

    var id: String {
        switch self {
        case .app(let app): app.url.path
        case .command(let command): command.id
        case .pane(let pane): pane.id
        case .file(let file): file.url.path
        }
    }

    var name: String {
        switch self {
        case .app(let app): app.name
        case .command(let command): command.name
        case .pane(let pane): pane.name
        case .file(let file): file.name
        }
    }

    var actions: [CommandAction] {
        switch self {
        case .app(let app):
            [
                CommandAction(id: "open", title: Self.openApp) {
                    _ = try await NSWorkspace.shared.openApplication(
                        at: app.url, configuration: NSWorkspace.OpenConfiguration())
                },
                Self.reveal(app.url),
            ]

        case .command(let command):
            command.actions

        case .pane(let pane):
            [pane.open]

        case .file(let file):
            [
                CommandAction(id: "open", title: "Open") {
                    _ = try await NSWorkspace.shared.open(
                        file.url, configuration: NSWorkspace.OpenConfiguration())
                },
                Self.reveal(file.url),
            ]
        }
    }

    private var keys: [Fuzzy.Key] {
        switch self {
        case .app(let app): app.keys.map(Fuzzy.Key.init)
        case .command(let command): ([command.name] + command.keywords).map(Fuzzy.Key.init)
        case .pane(let pane): pane.keys.map(Fuzzy.Key.init)
        case .file(let file): [file.key]
        }
    }

    static func sections(
        for query: String, in sources: Sources, usage: Usage, items: ItemSettings
    ) -> [ResultList.Section] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let typed = !trimmed.isEmpty
        let now = Date.now
        let rank = { (results: [Self]) in
            items.rank(
                results, by: query, bonus: { usage.bonus(for: $0, at: now) }, id: \.id,
                keys: \.keys)
        }
        let aliased = items.ids(withAlias: trimmed)
        let files = typed ? sources.files.files.map(Self.file) : []
        let hoisted = aliased.isEmpty ? [] : files.filter { aliased.contains($0.id) }
        let candidates =
            typed
            ? sources.apps.apps.map(Self.app) + SettingsPane.all.map(Self.pane)
                + sources.commands.map(Self.command) + hoisted
            : sources.commands.filter { !items.favourites.contains($0.id) }.map(Self.command)
        let ranked = rank(candidates)
        let found = rank(aliased.isEmpty ? files : files.filter { !aliased.contains($0.id) })
        let favourites = typed ? [] : items.favourites.compactMap { result(for: $0, in: sources) }
        let item = { (result: Self) in result.item(icons: sources.apps, at: now) }
        let results = [
            ResultList.Section(title: "Favourites", items: favourites.map(item)),
            ResultList.Section(title: typed ? "Results" : "Commands", items: ranked.map(item)),
            ResultList.Section(title: "Files", items: found.prefix(fileLimit).map(item)),
        ]
        let answer =
            ColourAnswer.section(for: trimmed)
            ?? Calculator.answer(for: trimmed, rates: sources.rates).map { answer in
                ResultList.Section(title: answer.kind, items: [Self.item(for: answer)])
            } ?? DictionaryAnswer.section(for: trimmed)
        guard let answer else {
            if typed, ranked.isEmpty, found.isEmpty {
                return [Fallback.section(for: trimmed, matched: false)]
            }
            return results
        }
        return [answer] + results + [Fallback.section(for: trimmed, matched: true)]
    }

    static func result(for id: String, in sources: Sources) -> Self? {
        if let file = sources.files.files.first(where: { $0.url.path == id }) {
            return .file(file)
        }
        if let pane = SettingsPane.all.first(where: { $0.id == id }) {
            return .pane(pane)
        }
        if let app = sources.apps.apps.first(where: { $0.url.path == id }) {
            return .app(app)
        }
        return sources.commands.first { $0.id == id }.map(Self.command)
    }

    static func context(for sections: [ResultList.Section]) -> (title: String?, symbol: String?) {
        if sections.contains(where: { $0.notice != nil }) { return ("No results", nil) }
        if sections.contains(where: { $0.colour != nil }) {
            return (ColourAnswer.context, ColourAnswer.symbol)
        }
        let answer = sections.first { section in
            section.card != nil || section.items.contains { $0.answer != nil }
        }
        return (answer?.title, nil)
    }

    static func actions(
        for id: String, query: String, in sources: Sources
    ) -> [CommandAction] {
        if id == answerID, let answer = Calculator.answer(for: query, rates: sources.rates) {
            return [
                CommandAction(id: "copy", title: "Copy Answer") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(answer.result, forType: .string)
                }
            ]
        }
        if DictionaryAnswer.ids.contains(id) {
            return DictionaryAnswer.actions(for: id, query: query)
        }
        if ColourAnswer.owns(id) {
            return ColourAnswer.actions(for: id, query: query)
        }
        if let fallback = Fallback.all.first(where: { $0.item.id == id }) {
            return [fallback.action(for: query.trimmingCharacters(in: .whitespacesAndNewlines))]
        }
        return result(for: id, in: sources)?.actions ?? []
    }

    private static func reveal(_ url: URL) -> CommandAction {
        CommandAction(id: "reveal", title: "Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private static func item(for file: FileIndex.File, at now: Date) -> ResultList.Item {
        ResultList.Item(
            id: file.url.path, title: file.name, subtitle: file.folder,
            kind: FileIndex.kind(of: file, at: now), symbol: "", action: "Open",
            icon: NSWorkspace.shared.icon(forFile: file.url.path), file: file.url)
    }

    private static func item(for answer: Calculator.Answer) -> ResultList.Item {
        ResultList.Item(
            id: answerID, title: answer.expression, subtitle: answer.expressionDetail,
            kind: answer.kind, symbol: "", action: "Copy Answer",
            answer: ResultList.Answer(value: answer.result, detail: answer.resultDetail))
    }

    private func item(icons apps: AppIndex, at now: Date) -> ResultList.Item {
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

        case .file(let file):
            Self.item(for: file, at: now)
        }
    }
}
