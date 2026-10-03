public struct SnippetSettings: Codable, Equatable, Sendable {
    private enum CodingKeys: CodingKey {
        case snippets
        case expands
        case addedApps
        case removedApps
    }

    public static let defaultAppsWithoutExpansion = ["com.apple.Terminal"]

    public private(set) var snippets: [Snippet]
    public var expands: Bool
    private var withoutExpansion: AppList

    public var appsWithoutExpansion: [String] {
        withoutExpansion.apps
    }

    public init() {
        snippets = []
        expands = true
        withoutExpansion = AppList(defaults: Self.defaultAppsWithoutExpansion)
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        snippets = try values.decodeIfPresent([Snippet].self, forKey: .snippets) ?? snippets
        expands = try values.decodeIfPresent(Bool.self, forKey: .expands) ?? expands
        withoutExpansion = try AppList(
            defaults: Self.defaultAppsWithoutExpansion, from: values, added: .addedApps,
            removed: .removedApps)
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(snippets, forKey: .snippets)
        try values.encode(expands, forKey: .expands)
        try withoutExpansion.encode(to: &values, added: .addedApps, removed: .removedApps)
    }

    public func expands(in app: String?) -> Bool {
        expands && !(app.map(withoutExpansion.contains) ?? false)
    }

    public func snippet(withKeyword keyword: String) -> Snippet? {
        snippets.first { $0.keyword == keyword }
    }

    public func snippet(overlapping keyword: String, besides id: String?) -> Snippet? {
        snippets.first { other in
            other.id != id && !other.keyword.isEmpty && !keyword.isEmpty
                && (other.keyword == keyword || keyword.dropLast().contains(other.keyword)
                    || other.keyword.dropLast().contains(keyword))
        }
    }

    public mutating func stopExpanding(in app: String) {
        withoutExpansion.add(app)
    }

    public mutating func expandAgain(in app: String) {
        withoutExpansion.remove(app)
    }

    public mutating func save(_ snippet: Snippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index] = snippet
        } else {
            snippets.append(snippet)
        }
    }

    public mutating func remove(_ id: String) {
        snippets.removeAll { $0.id == id }
    }
}
