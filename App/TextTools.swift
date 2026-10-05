import AppCore
import AppKit
import ClipboardKit
import GlassUI
import os
import WindowKit

@MainActor
final class TextTools {
    struct Source {
        let text: String
        let origin: (label: String, name: String)
        let isSelection: Bool
        let counts: String
        let outcomes: [TextTool: TextTool.Outcome]

        init(text: String, origin: (label: String, name: String), isSelection: Bool) {
            self.text = text
            self.origin = origin
            self.isSelection = isSelection
            let tally = TextTool.Counts(of: text)
            counts = [
                Self.counted(tally.lines, "line"), Self.counted(tally.words, "word"),
                Self.counted(tally.characters, "character"),
            ].joined(separator: " · ")
            outcomes = Dictionary(
                uniqueKeysWithValues: TextTool.allCases.map { ($0, $0.apply(to: text)) })
        }

        private static func counted(_ count: Int, _ noun: String) -> String {
            "\(count.formatted()) \(noun)\(count == 1 ? "" : "s")"
        }
    }

    static let commandID = "text.tools"
    static let title = "Text Tools"
    static let symbol = "text.alignleft"
    static let placeholder = "Filter tools"
    static let chip = LauncherView.Chip(title: "Selected text", symbol: symbol)
    static let capsule: [LauncherView.CapsuleSlot] = [
        .primary, .keyed(LauncherView.Action.secondaryKeys),
    ]
    private static let toolPrefix = "text.tools."
    static let commandIDs = [commandID] + TextTool.allCases.map { toolPrefix + $0.rawValue }
    private static let replaceTitle = "Replace Selection"
    private static let logger = Log.logger("TextTools")

    var onOpen: (() -> Void)?
    var onRead: (() -> Void)?
    var findTarget: (() -> PasteTarget?)?
    private var store: ClipboardStore?
    private var source: Source?
    private var pasteTarget: PasteTarget?
    private var request = 0
    private var reading = false

    private static func tool(for id: String) -> TextTool? {
        id.hasPrefix(toolPrefix) ? TextTool(rawValue: String(id.dropFirst(toolPrefix.count))) : nil
    }

    private static func selection(in target: PasteTarget) async -> String? {
        await FocusedText.selection(in: target.app.processIdentifier)
    }

    func start(with store: ClipboardStore, context: ModuleContext) {
        self.store = store
        context.own(.other, "text tools") { [weak self] in self?.stop() }
        let open = CommandAction(id: "open", title: "Open \(Self.title)") { [weak self] in
            await self?.open()
        }
        let commands =
            [
                Command(
                    id: Self.commandID, name: Self.title, icon: Self.symbol, actions: [open],
                    keywords: ["text", "selection", "transform", "convert", "encode", "decode"])
            ]
            + TextTool.allCases.map { tool in
                let run = CommandAction(id: "run", title: tool.title) { [weak self] in
                    try await self?.run(tool)
                }
                return Command(
                    id: Self.toolPrefix + tool.rawValue, name: tool.title, icon: tool.symbol,
                    actions: [run], keywords: ["text", "selection", "tools"])
            }
        for command in commands {
            do {
                try context.register(command)
            } catch {
                context.logger.error(
                    "Text tool \(command.id, privacy: .public) failed: \(error, privacy: .public)")
            }
        }
    }

    private func stop() {
        store = nil
        close()
    }

    func close() {
        request += 1
        reading = false
        source = nil
        pasteTarget = nil
    }

    private func read(from target: PasteTarget?) async -> Source? {
        if let target, let text = await Self.selection(in: target) {
            let name = target.app.localizedName ?? "the previous app"
            return await Task.detached {
                Source(text: text, origin: ("Selected in", name), isSelection: true)
            }.value
        }
        let latest: ClipboardStore.Entry?
        do {
            latest = try await store?.search("", limit: 1).first
        } catch {
            Self.logger.error("Reading the latest copy failed: \(error, privacy: .public)")
            return nil
        }
        guard let latest, let text = latest.plainText, !text.isEmpty else { return nil }
        let origin =
            latest.source.map { ("Copied from", ClipboardHistory.app($0).name) }
            ?? ("Latest copy in", ClipboardHistory.title)
        return await Task.detached {
            Source(text: text, origin: origin, isSelection: false)
        }.value
    }

    private func open() async {
        let found = findTarget?()
        source = nil
        pasteTarget = found
        request += 1
        let current = request
        reading = true
        onOpen?()
        let read = await read(from: found)
        guard current == request else { return }
        reading = false
        source = read
        onRead?()
    }

    private func run(_ tool: TextTool) async throws {
        guard let target = findTarget?(), let selection = await Self.selection(in: target),
            let output = await Task.detached(operation: { tool.apply(to: selection).output }).value,
            await Self.selection(in: target) == selection
        else {
            NSSound.beep()
            return
        }
        try await target.action(pasting: output).perform()
    }

    func sections(for query: String) -> [ResultList.Section] {
        guard let source else {
            let notice =
                reading
                ? ResultList.Notice(title: "Reading the text…", detail: "")
                : ResultList.Notice(
                    title: "No text to work on",
                    detail: "Select text in an app or copy some, then open Text Tools again.")
            return [ResultList.Section(title: "", items: [], notice: notice)]
        }
        let needle = query.trimmingCharacters(in: .whitespaces)
        let tools = TextTool.allCases.filter { tool in
            needle.isEmpty || tool.title.localizedCaseInsensitiveContains(needle)
        }
        guard !tools.isEmpty else {
            let notice = ResultList.Notice(
                title: "No tools match “\(needle)”", detail: "Try case, sort, URL, Base64 or JSON.")
            return [ResultList.Section(title: "", items: [], notice: notice)]
        }
        let action =
            pasteTarget.map { source.isSelection ? Self.replaceTitle : $0.title } ?? ""
        return [
            ResultList.Section(
                title: Self.title,
                items: tools.map { tool in
                    let outcome = source.outcomes[tool] ?? .invalid
                    var item = ResultList.Item(
                        id: Self.toolPrefix + tool.rawValue, title: tool.title,
                        subtitle: tool.summary(of: outcome, from: source.text), kind: "",
                        symbol: tool.symbol, action: outcome.output == nil ? "" : action)
                    item.isDimmed = outcome.output == nil
                    return item
                })
        ]
    }

    func comparison(for item: ResultList.Item) -> LauncherView.Comparison? {
        guard let source, let tool = Self.tool(for: item.id) else { return nil }
        let outcome = source.outcomes[tool] ?? .invalid
        let output = outcome.output
        return LauncherView.Comparison(
            source: source.origin, counts: source.counts, before: source.text,
            struck: tool == .removeDuplicateLines && output != nil
                ? TextTool.duplicateLines(in: source.text) : [],
            after: output ?? tool.summary(of: outcome, from: source.text),
            changes: output != nil)
    }

    func actions(for id: String) -> [(action: CommandAction, keys: [String])] {
        guard let source, let tool = Self.tool(for: id),
            let output = source.outcomes[tool]?.output
        else { return [] }
        let copy = CommandAction(id: "copy", title: "Copy") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(output, forType: .string)
        }
        guard let pasteTarget else { return [(copy, LauncherView.Action.secondaryKeys)] }
        let paste = pasteTarget.action(pasting: output)
        let replace = CommandAction(
            id: paste.id, title: source.isSelection ? Self.replaceTitle : paste.title
        ) {
            if source.isSelection, await Self.selection(in: pasteTarget) != source.text {
                NSSound.beep()
                return
            }
            try await paste.perform()
        }
        return [
            (replace, LauncherView.Action.primaryKeys), (copy, LauncherView.Action.secondaryKeys),
        ]
    }
}
