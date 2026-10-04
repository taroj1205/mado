public enum HotKey: Hashable, Sendable, Codable {
    case modifierTap(ModifierKey)
    case shortcut(Shortcut)

    public enum ModifierKey: String, Hashable, Sendable, Codable {
        case leftCommand = "left_command"
        case leftControl = "left_control"
        case leftOption = "left_option"
        case leftShift = "left_shift"
        case rightCommand = "right_command"
        case rightControl = "right_control"
        case rightOption = "right_option"
        case rightShift = "right_shift"
    }

    private enum CodingKeys: String, CodingKey {
        case modifierTap = "modifier_tap"
        case shortcut = "shortcut"
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if let key = try values.decodeIfPresent(ModifierKey.self, forKey: .modifierTap) {
            self = .modifierTap(key)
        } else {
            self = .shortcut(try values.decode(Shortcut.self, forKey: .shortcut))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .modifierTap(let key): try values.encode(key, forKey: .modifierTap)
        case .shortcut(let shortcut): try values.encode(shortcut, forKey: .shortcut)
        }
    }
}
