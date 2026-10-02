import AppCore
import AppKit
import GlassUI
import SearchKit

@MainActor
struct Fallback {
    enum Failure: Error {
        case badQuery
        case finderUnavailable
    }

    static let all = [
        Self(
            "fallback.web", "Search Google", subtitle: "google.com", kind: "Web",
            symbol: "globe"
        ) { query in
            guard let url = WebSearch.googleURL(for: query) else { throw Failure.badQuery }
            _ = try await NSWorkspace.shared.open(
                url, configuration: NSWorkspace.OpenConfiguration())
        },
        Self(
            "fallback.files", "Search Files", subtitle: "Spotlight index", kind: "Files",
            symbol: "doc.text"
        ) { query in
            guard NSWorkspace.shared.showSearchResults(forQueryString: query) else {
                throw Failure.finderUnavailable
            }
        },
    ]

    let item: ResultList.Item
    private let search: @MainActor @Sendable (String) async throws -> Void

    private init(
        _ id: String, _ title: String, subtitle: String, kind: String, symbol: String,
        search: @escaping @MainActor @Sendable (String) async throws -> Void
    ) {
        item = ResultList.Item(
            id: id, title: title, subtitle: subtitle, kind: kind, symbol: symbol, action: title)
        self.search = search
    }

    static func section(for query: String, matched: Bool) -> ResultList.Section {
        ResultList.Section(
            title: "Use “\(query)” with…", items: all.map(\.item),
            notice: matched
                ? nil
                : ResultList.Notice(
                    title: "No matches for “\(query)”",
                    detail: "Try one of these instead, or check the spelling."))
    }

    func action(for query: String) -> CommandAction {
        CommandAction(id: "search", title: item.title) { [search] in try await search(query) }
    }
}
