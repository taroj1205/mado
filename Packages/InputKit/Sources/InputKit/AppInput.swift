public enum AppInput: Codable, Equatable, Sendable {
    case lastUsed
    case source(id: String)

    private enum CodingKeys: String, CodingKey {
        case lastUsed = "last_used"
        case source = "source"
    }
}
