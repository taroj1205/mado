import AppCore
import AppKit
import ClipboardKit
import GlassUI
import SearchKit
import WindowKit

@MainActor
enum LauncherResult {
    case app(AppIndex.App)
    case command(Command)
    case file(FileIndex.File)
    case pane(SettingsPane)
    case quicklink(Quicklink, query: String = "")
    case setting(SettingsLink)

    private static let openApp = "Open Application"
    private static let answerID = "calculator"
    private static let fileLimit = 20
    private static let searchSymbol = "magnifyingglass"
    private static let answerSymbol = "plus.forwardslash.minus"

    var id: String {
        switch self {
        case .app(let app): app.url.path
        case .command(let command): command.id
        case .pane(let pane): pane.id
        case .file(let file): file.path
        case .quicklink(let link, _): link.id
        case .setting(let link): link.id
        }
    }

    var name: String {
        switch self {
        case .app(let app): app.name
        case .command(let command): command.name
        case .pane(let pane): pane.name
        case .file(let file): file.name
        case .quicklink(let link, _): link.name
        case .setting(let link): link.name
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

        case let .quicklink(link, query):
            [link.open(query: query)]

        case .setting(let link):
            [link.open]
        }
    }

    private var keys: [Fuzzy.Key] {
        switch self {
        case .app(let app): app.keys
        case .command(let command): ([command.name] + command.keywords).map(Fuzzy.Key.init)
        case .pane(let pane): pane.keys.map(Fuzzy.Key.init)
        case .file(let file): [file.key]
        case .quicklink(let link, _): [Fuzzy.Key(link.name)]
        case .setting(let link): [Fuzzy.Key(link.name)]
        }
    }

    static func sections(
        for query: String, in sources: Sources, usage: Usage
    ) async -> [ResultList.Section] {
        let items = sources.items
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let typed = !trimmed.isEmpty
        let now = Date.now
        let aliased = items.ids(withAlias: trimmed)
        let files = typed ? sources.files.files : []
        async let rankedFiles = FileIndex.rank(
            aliased.isEmpty ? files : files.filter { !aliased.contains($0.path) },
            by: query, items: items, usage: usage, at: now)
        let (filled, links) = quicklinks(for: trimmed, in: sources)
        let hoisted =
            aliased.isEmpty ? [] : files.filter { aliased.contains($0.path) }.map(Self.file)
        let candidates =
            typed
            ? sources.apps.apps.map(Self.app) + SettingsPane.all.map(Self.pane)
                + sources.commands.map(Self.command) + links + hoisted
            : sources.commands.filter { !items.favourites.contains($0.id) }.map(Self.command)
        let ranked =
            filled
            + items.rank(
                candidates, by: query, bonus: { usage.bonus(for: $0, at: now) }, id: \.id,
                keys: \.keys)
        let favourites = typed ? [] : items.favourites.compactMap { result(for: $0, in: sources) }
        let item = { (result: Self) in
            result.item(icons: sources.apps, hotkey: items.hotkeys[result.id], at: now)
        }
        let found = await rankedFiles.prefix(fileLimit).map(Self.file)
        let results = [
            ResultList.Section(title: "Favourites", items: favourites.map(item)),
            ResultList.Section(title: typed ? "Results" : "Commands", items: ranked.map(item)),
            ResultList.Section(
                title: SettingsLink.kind,
                items: settingResults(for: trimmed, in: sources).map(item)),
            ResultList.Section(title: "Files", items: found.map(item)),
        ]
        guard let answer = answerSection(for: trimmed, in: sources) else {
            let isEmpty = typed && results.allSatisfy(\.items.isEmpty)
            return isEmpty ? [Fallback.section(for: trimmed, matched: false)] : results
        }
        return [answer] + results + [Fallback.section(for: trimmed, matched: true)]
    }

    static func result(for id: String, in sources: Sources) -> Self? {
        if let link = SettingsLink(id: id, opening: sources.openSetting) {
            return .setting(link)
        }
        if let file = sources.files.file(atPath: id) {
            return .file(file)
        }
        if let pane = SettingsPane.all.first(where: { $0.id == id }) {
            return .pane(pane)
        }
        if let app = sources.apps.app(atPath: id) {
            return .app(app)
        }
        if let link = sources.quicklinks.first(where: { $0.id == id }) {
            return .quicklink(link)
        }
        return sources.commands.first { $0.id == id }.map(Self.command)
    }

    static func context(
        for sections: [ResultList.Section], query: String
    ) -> (title: String?, symbol: String?) {
        if sections.contains(where: { $0.notice != nil }) { return ("No results", searchSymbol) }
        if sections.contains(where: { $0.colour != nil }) {
            return (ColourAnswer.context, ColourAnswer.symbol)
        }
        let answer = sections.first { section in
            section.card != nil || section.items.contains { $0.answer != nil }
        }
        if let answer {
            return (answer.title, answer.card == nil ? answerSymbol : DictionaryAnswer.symbol)
        }
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (nil, nil)
        }
        let count = sections.reduce(0) { $0 + $1.items.count }
        return (count == 1 ? "1 result" : "\(count) results", searchSymbol)
    }

    static func actions(
        for id: String, query: String, in sources: Sources, pastingInto target: PasteTarget?
    ) -> [CommandAction] {
        if let link = sources.quicklinks.first(where: { $0.id == id }) {
            let aliases = sources.items[id].aliases
            return [link.open(query: link.query(in: query, aliases: aliases) ?? "")]
        }
        if id == answerID, let answer = answer(for: query, in: sources) {
            let copy = CommandAction(id: "copy", title: "Copy Answer") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(answer.result, forType: .string)
            }
            guard let target else { return [copy] }
            return [copy, target.action(pasting: answer.result)]
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

    private static func quicklinks(
        for query: String, in sources: Sources
    ) -> (filled: [Self], others: [Self]) {
        var filled: [Self] = []
        var others: [Self] = []
        for link in sources.quicklinks {
            if let typed = link.query(in: query, aliases: sources.items[link.id].aliases) {
                filled.append(.quicklink(link, query: typed))
            } else {
                others.append(.quicklink(link))
            }
        }
        return (filled, others)
    }

    private static func answerSection(
        for query: String, in sources: Sources
    ) -> ResultList.Section? {
        let shows = sources.answers.shows
        return (shows(.colours) ? ColourAnswer.section(for: query) : nil)
            ?? Self.answer(for: query, in: sources).map { answer in
                ResultList.Section(title: answer.kind, items: [Self.item(for: answer)])
            } ?? (shows(.dictionary) ? DictionaryAnswer.section(for: query) : nil)
    }

    static func answer(for query: String, in sources: Sources) -> Calculator.Answer? {
        Calculator.answer(for: query, rates: sources.rates, settings: sources.answers)
    }

    private static func reveal(_ url: URL) -> CommandAction {
        CommandAction(id: "reveal", title: "Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private static func item(for file: FileIndex.File, at now: Date) -> ResultList.Item {
        ResultList.Item(
            id: file.path, title: file.name, subtitle: file.folder,
            kind: FileIndex.kind(of: file, at: now), symbol: "", action: "Open",
            icon: NSWorkspace.shared.icon(forFile: file.path), file: file.url)
    }

    static func item(for answer: Calculator.Answer) -> ResultList.Item {
        ResultList.Item(
            id: answerID, title: answer.expression, subtitle: answer.expressionDetail,
            kind: answer.kind, symbol: "", action: "Copy Answer",
            answer: ResultList.Answer(value: answer.result, detail: answer.resultDetail))
    }

    private func item(icons apps: AppIndex, hotkey: Shortcut?, at now: Date) -> ResultList.Item {
        var item: ResultList.Item =
            switch self {
            case .app(let app):
                ResultList.Item(
                    id: id, title: app.name, subtitle: app.folder, kind: "Application", symbol: "",
                    action: Self.openApp, icon: apps.icon(for: app))

            case .command(let command):
                ResultList.Item(
                    id: id, title: command.name, subtitle: "", kind: "Command",
                    symbol: command.icon, action: "Run Command")

            case .pane(let pane):
                pane.item

            case .setting(let link):
                link.item

            case .file(let file):
                Self.item(for: file, at: now)

            case let .quicklink(link, query):
                ResultList.Item(
                    id: id, title: link.name, subtitle: link.text(for: query), kind: "Quicklink",
                    symbol: "link", action: Quicklink.openTitle, icon: link.image)
            }
        item.hotkey = hotkey
        return item
    }
}
