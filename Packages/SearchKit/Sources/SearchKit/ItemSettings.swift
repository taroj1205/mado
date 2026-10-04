public import AppCore
import Foundation

public struct ItemSettings: Codable, Equatable, Sendable {
    public struct Item: Equatable, Sendable {
        public var aliases: [String]
        public var hotkey: Shortcut?
        public var favourite: Bool
        public var quickPeek: Bool

        public init(
            aliases: [String] = [], hotkey: Shortcut? = nil, favourite: Bool = false,
            quickPeek: Bool = false
        ) {
            self.aliases = aliases
            self.hotkey = hotkey
            self.favourite = favourite
            self.quickPeek = quickPeek
        }
    }

    static let aliasBonus = 1 << 20

    public private(set) var hotkeys: [String: Shortcut]
    public private(set) var favourites: [String]
    private var aliases: [String: [String]]
    private var peeks: Set<String>

    public init() {
        hotkeys = [:]
        favourites = []
        aliases = [:]
        peeks = []
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        hotkeys = try values.decode([String: Shortcut].self, forKey: .hotkeys)
        favourites = try values.decode([String].self, forKey: .favourites)
        aliases = try values.decode([String: [String]].self, forKey: .aliases)
        peeks = try values.decodeIfPresent(Set<String>.self, forKey: .peeks) ?? []
    }

    static func fold(_ text: String) -> String {
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
        let aliasKeys = aliases.mapValues { $0.map(Fuzzy.Key.init) }
        return Fuzzy.rank(
            items, by: query,
            bonus: { item in
                let itemID = id(item)
                return bonus(itemID) + (aliased.contains(itemID) ? Self.aliasBonus : 0)
            },
            keys: { item in
                aliasKeys.isEmpty ? keys(item) : (aliasKeys[id(item)] ?? []) + keys(item)
            })
    }

    public subscript(id: String) -> Item {
        get {
            Item(
                aliases: aliases[id] ?? [], hotkey: hotkeys[id],
                favourite: favourites.contains(id), quickPeek: peeks.contains(id))
        }
        set {
            aliases[id] = newValue.aliases.isEmpty ? nil : newValue.aliases
            hotkeys[id] = newValue.hotkey
            if newValue.quickPeek {
                peeks.insert(id)
            } else {
                peeks.remove(id)
            }
            if !newValue.favourite {
                favourites.removeAll { $0 == id }
            } else if !favourites.contains(id) {
                favourites.append(id)
            }
        }
    }
}
