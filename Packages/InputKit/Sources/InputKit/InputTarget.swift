public enum InputTarget: Codable, Hashable, Sendable {
    case english
    case japanese
    case next
    case source(id: String)

    private enum CodingKeys: String, CodingKey {
        case english = "eisu"
        case japanese = "kana"
        case next = "next_source"
        case source = "source"
    }

    @MainActor
    public func select() {
        switch self {
        case .english: InputMode.english.select()
        case .japanese: InputMode.japanese.select()
        case .next: InputSource.selectNext()
        case .source(let id): InputSource.select(id)
        }
    }
}
