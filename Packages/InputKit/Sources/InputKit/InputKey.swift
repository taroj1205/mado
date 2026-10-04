public import AppCore

public struct InputKey: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case target = "target"
        case hotKey = "hot_key"
    }

    public let target: InputTarget
    public let hotKey: HotKey
}
