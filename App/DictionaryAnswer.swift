import AppCore
import AppKit
import GlassUI
import SearchKit

@MainActor
enum DictionaryAnswer {
    static let title = "Dictionary"
    private static let openID = "dictionary.open"
    private static let copyID = "dictionary.copy"
    private static let japaneseID = "dictionary.japanese"
    static let ids: Set = [openID, copyID, japaneseID]
    private static let open = "Open in Dictionary"
    private static let copy = "Copy Definition"
    private static let japanese = "Look Up in 大辞林"
    private static let book = "book.closed"
    private static let dictionaryRed: CGFloat = 0.42
    private static let dictionaryGreen: CGFloat = 0.31
    private static let dictionaryBlue: CGFloat = 0.165
    private static let japaneseRed: CGFloat = 0.557
    private static let japaneseGreen: CGFloat = 0.231
    private static let japaneseBlue: CGFloat = 0.184
    private static let dictionaryTint = NSColor(
        srgbRed: dictionaryRed, green: dictionaryGreen, blue: dictionaryBlue, alpha: 1)
    private static let japaneseTint = NSColor(
        srgbRed: japaneseRed, green: japaneseGreen, blue: japaneseBlue, alpha: 1)

    static func section(for query: String) -> ResultList.Section? {
        guard let entry = entry(for: query) else { return nil }
        let detail = [entry.pronunciation, entry.partOfSpeech].filter { !$0.isEmpty }
        let card = ResultList.Card(
            title: entry.headword, detail: detail.joined(separator: " · "), text: entry.definition,
            similar: entry.similar.map { word in
                .init(title: word, query: DictionaryLookup.query(for: word, replacing: query))
            },
            opposite: entry.opposite)
        let rows = [
            ResultList.Item(
                id: openID, title: open, subtitle: entry.dictionary, kind: "", symbol: book,
                action: open, tint: dictionaryTint, shortcut: ["↵"]),
            ResultList.Item(
                id: copyID, title: copy, subtitle: "", kind: "", symbol: "doc.on.doc",
                action: copy, shortcut: ["⌘", "↵"]),
        ]
        let japaneseRow = ResultList.Item(
            id: japaneseID, title: japanese, subtitle: "Japanese dictionary", kind: "",
            symbol: book, action: japanese, tint: japaneseTint)
        return ResultList.Section(
            title: title, items: rows + (entry.japaneseURL == nil ? [] : [japaneseRow]),
            card: card)
    }

    static func actions(for id: String, query: String) -> [CommandAction] {
        guard let entry = entry(for: query) else { return [] }
        let openAction = CommandAction(id: "open", title: open) { try await show(entry.url) }
        let copyAction = CommandAction(id: "copy", title: copy) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(entry.definition, forType: .string)
        }
        let japaneseActions = entry.japaneseURL.map { url in
            [CommandAction(id: "japanese", title: japanese) { try await show(url) }]
        }
        switch id {
        case openID: return [openAction, copyAction] + (japaneseActions ?? [])
        case copyID: return [copyAction]
        default: return japaneseActions ?? []
        }
    }

    private static func entry(for query: String) -> DictionaryLookup.Entry? {
        DictionaryLookup.term(in: query).flatMap(DictionaryLookup.entry)
    }

    private static func show(_ url: URL) async throws {
        _ = try await NSWorkspace.shared.open(url, configuration: NSWorkspace.OpenConfiguration())
    }
}
