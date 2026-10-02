public import Foundation

public struct Quicklink: Codable, Equatable, Sendable {
    public static let placeholder = "{query}"
    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    public let id: String
    public var name: String
    public var link: String
    public var app: URL?
    public var icon: Data?

    public init(
        name: String, link: String, app: URL? = nil, icon: Data? = nil,
        id: String = "quicklink." + UUID().uuidString
    ) {
        self.id = id
        self.name = name
        self.link = link
        self.app = app
        self.icon = icon
    }

    public func url(for query: String) -> URL? {
        let template = link.trimmingCharacters(in: .whitespacesAndNewlines)
        if template.hasPrefix("/") || template == "~" || template.hasPrefix("~/") {
            let path = template.replacing(Self.placeholder, with: query)
            let home = path.hasPrefix("~") ? NSHomeDirectory() + path.dropFirst() : path
            return URL(filePath: home)
        }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: Self.unreserved) ?? ""
        let filled = template.replacing(Self.placeholder, with: encoded)
        guard let url = URL(string: filled) else { return nil }
        return url.scheme == nil ? URL(string: "https://" + filled) : url
    }

    public func query(in text: String, aliases: [String]) -> String? {
        guard link.contains(Self.placeholder) else { return nil }
        let typed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for alias in aliases.map(ItemSettings.fold) where !alias.isEmpty {
            let rest = typed.dropFirst(alias.count)
            guard rest.first?.isWhitespace == true,
                ItemSettings.fold(String(typed.prefix(alias.count))) == alias
            else { continue }
            return rest.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}
