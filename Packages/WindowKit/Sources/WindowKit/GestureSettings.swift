public import AppCore

public struct GestureSettings: Codable, Equatable, Sendable {
    public var move: Shortcut.Modifiers
    public var resize: Shortcut.Modifiers

    public init() {
        move = [.function, .control]
        resize = [.function, .control, .option]
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        move = try values.decodeIfPresent(Shortcut.Modifiers.self, forKey: .move) ?? move
        resize = try values.decodeIfPresent(Shortcut.Modifiers.self, forKey: .resize) ?? resize
    }
}
