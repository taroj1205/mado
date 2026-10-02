public import AppCore
import Foundation

public struct ItemSettings: Codable, Equatable, Sendable {
    public struct Item: Equatable, Sendable {
        public var aliases: [String]
        public var hotkey: Shortcut?
        public var favourite: Bool

        public init(aliases: [String] = [], hotkey: Shortcut? = nil, favourite: Bool = false) {
            self.aliases = aliases
            self.hotkey = hotkey
            self.favourite = favourite
        }
    }

    static let aliasBonus = 1 << 20

    public private(set) var hotkeys: [String: Shortcut]
    public private(set) var favourites: [String]
    private var aliases: [String: [String]]

    public init() {
        hotkeys = [:]
        favourites = []
        aliases = [:]
    }

    private static func fold(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .widthInsensitive], locale: nil)
    }

    public func owner(of hotkey: Shortcut) -> String? {
        hotkeys.first { $0.value == hotkey }?.key
    }

    public func ids(withAlias query: String) -> Set<String> {
        let wanted = Self.fold(query)
        guard !wanted.isEmpty else { return [] }
        return Set(aliases.filter { $0.value.contains { Self.fold($0) == wanted } }.keys)
    }

    public func rank<Item>(
        _ items: [Item], by query: String, bonus: (String) -> Int, id: (Item) -> String,
        keys: (Item) -> [Fuzzy.Key]
    ) -> [Item] {
        let aliased = ids(withAlias: query)
        let tagged = items.map { (item: $0, id: id($0)) }
        let ranked = Fuzzy.rank(
            tagged, by: query,
            bonus: { bonus($0.id) + (aliased.contains($0.id) ? Self.aliasBonus : 0) },
            keys: { (aliases[$0.id] ?? []).map(Fuzzy.Key.init) + keys($0.item) })
        return ranked.map(\.item)
    }

    public subscript(id: String) -> Item {
        get {
            Item(
                aliases: aliases[id] ?? [], hotkey: hotkeys[id],
                favourite: favourites.contains(id))
        }
        set {
            aliases[id] = newValue.aliases.isEmpty ? nil : newValue.aliases
            hotkeys[id] = newValue.hotkey
            if !newValue.favourite {
                favourites.removeAll { $0 == id }
            } else if !favourites.contains(id) {
                favourites.append(id)
            }
        }
    }
}
