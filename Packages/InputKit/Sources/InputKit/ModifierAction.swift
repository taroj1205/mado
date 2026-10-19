public enum ModifierAction: Codable, Hashable, Sendable {
    case inputSource(target: InputTarget)
    case item(id: String)

    private enum CodingKeys: String, CodingKey {
        case inputSource = "input_source"
        case item = "item"
    }
}
