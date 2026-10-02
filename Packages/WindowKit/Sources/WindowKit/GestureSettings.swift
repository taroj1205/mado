public import AppCore

public struct GestureSettings: Codable, Equatable, Sendable {
    public enum Target: String, Codable, CaseIterable, Sendable {
        case activeWindow = "active_window"
        case underMouse = "under_mouse"
    }

    public var move: Shortcut.Modifiers
    public var resize: Shortcut.Modifiers
    public var target: Target

    public init() {
        move = [.function, .control]
        resize = [.function, .control, .option]
        target = .activeWindow
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        move = try values.decodeIfPresent(Shortcut.Modifiers.self, forKey: .move) ?? move
        resize = try values.decodeIfPresent(Shortcut.Modifiers.self, forKey: .resize) ?? resize
        target = try values.decodeIfPresent(Target.self, forKey: .target) ?? target
    }
}
