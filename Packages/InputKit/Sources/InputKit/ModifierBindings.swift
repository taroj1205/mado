public struct ModifierBindings: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public let modifiers: [ModifierTap.Key]
        public let count: Int
        public let action: ModifierAction

        public var tap: ModifierTap.Tap {
            ModifierTap.Tap(keys: Set(modifiers), count: count)
        }

        public init(tap: ModifierTap.Tap, action: ModifierAction) {
            modifiers = ModifierTap.Key.allCases.filter(tap.keys.contains)
            count = tap.count
            self.action = action
        }
    }

    private enum CodingKeys: String, CodingKey {
        case entries = "taps"
    }

    public private(set) var entries: [Entry]

    public init() {
        entries = []
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        let saved = try values.decodeIfPresent([Entry].self, forKey: .entries) ?? entries
        entries = saved.filter { !$0.modifiers.isEmpty && $0.count >= 1 }
    }

    public func action(for tap: ModifierTap.Tap) -> ModifierAction? {
        entries.first { $0.tap == tap }?.action
    }

    public mutating func bind(_ action: ModifierAction?, to tap: ModifierTap.Tap) {
        let replaced = entries.firstIndex { $0.tap == tap }
        entries.removeAll { $0.tap == tap }
        guard let action else { return }
        entries.insert(
            Entry(tap: tap, action: action), at: min(replaced ?? entries.count, entries.count))
    }
}
