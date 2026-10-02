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
    private static let answerID = "calculator"
    private static let colourPrefix = "colour."
    private static let fileLimit = 20
    private static let byte: CGFloat = 255
    private static let colourKind = "Colour"
    private static let colourSymbol = "paintpalette.fill"

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
        let results = [
            ResultList.Section(
                title: typed ? "Results" : "Commands", items: ranked.map { $0.item(icons: apps) }),
            ResultList.Section(
                title: "Files", items: found.prefix(fileLimit).map { item(for: $0, at: now) }),
        ]
        if let colour = Colour(trimmed) {
            return [section(for: colour)] + results + [
                Fallback.section(for: trimmed, matched: true)
            ]
        }
        guard let answer = Calculator.answer(for: trimmed) else {
            if typed, ranked.isEmpty, found.isEmpty {
                return [Fallback.section(for: trimmed, matched: false)]
            }
            return results
        }
        return [ResultList.Section(title: answer.kind, items: [item(for: answer)])] + results
            + [Fallback.section(for: trimmed, matched: true)]
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
                reveal(file.url),
            ]
        }
        if id == answerID, let answer = Calculator.answer(for: query) {
            return [copy(answer.result, title: "Copy Answer")]
        }
        if id.hasPrefix(colourPrefix) {
            let item = Colour(query).flatMap { colour in copies(of: colour).first { $0.id == id } }
            return item.map { [copy($0.subtitle, title: $0.action)] } ?? []
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
            },
            reveal(app.url),
        ]
    }

    static func context(of sections: [ResultList.Section]) -> (title: String?, symbol: String?) {
        if sections.contains(where: { $0.notice != nil }) { return ("No results", nil) }
        if sections.contains(where: { $0.colour != nil }) { return (colourKind, colourSymbol) }
        return (sections.lazy.flatMap(\.items).first { $0.answer != nil }?.kind, nil)
    }

    static func remembers(_ item: ResultList.Item) -> Bool {
        item.answer == nil && !item.id.hasPrefix(colourPrefix)
            && !Fallback.all.contains { $0.item.id == item.id }
    }

    private static func copy(_ text: String, title: String) -> CommandAction {
        CommandAction(id: "copy", title: title) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    private static func section(for colour: Colour) -> ResultList.Section {
        let swatch = NSColor(
            srgbRed: CGFloat(colour.red) / byte, green: CGFloat(colour.green) / byte,
            blue: CGFloat(colour.blue) / byte, alpha: 1)
        return ResultList.Section(
            title: "Copy as", items: copies(of: colour),
            colour: ResultList.ColourCard(
                swatch: swatch, hex: colour.hex, rgb: colour.rgb, hsl: colour.hsl,
                closest: colour.closestSystemColour, onWhite: colour.onWhite,
                onBlack: colour.onBlack))
    }

    private static func copies(of colour: Colour) -> [ResultList.Item] {
        [
            ("hex", "Copy HEX", colour.hex, "number", ["↵"]),
            ("rgb", "Copy RGB", colour.rgb, "doc.on.doc", ["⌘", "1"]),
            ("hsl", "Copy HSL", colour.hsl, "doc.on.doc", ["⌘", "2"]),
            (
                "appkit", "Copy for AppKit", colour.appKit,
                "chevron.left.forwardslash.chevron.right",
                ["⌘", "3"]
            ),
        ].map { id, title, value, symbol, keys in
            ResultList.Item(
                id: colourPrefix + id, title: title, subtitle: value, kind: colourKind,
                symbol: symbol, action: title, keys: keys)
        }
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
