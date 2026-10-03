import IOKit.hid

public struct RemapSettings: Codable, Equatable, Sendable {
    public enum CapsLock: String, Codable, CaseIterable, Sendable {
        case capsLock = "caps_lock"
        case control = "control"
        case escape = "escape"
        case hyper = "hyper"

        var usage: UInt64? {
            switch self {
            case .capsLock: nil
            case .control: KeyMappings.usage(kHIDUsage_KeyboardLeftControl)
            case .escape: KeyMappings.usage(kHIDUsage_KeyboardEscape)
            case .hyper: KeyMappings.usage(kHIDUsage_KeyboardF18)
            }
        }
    }

    public var capsLock: CapsLock
    public var tapSendsEscape: Bool
    public var excludedKeyboards: [Keyboard]

    public init() {
        capsLock = .capsLock
        tapSendsEscape = false
        excludedKeyboards = []
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        capsLock = try values.decodeIfPresent(CapsLock.self, forKey: .capsLock) ?? capsLock
        tapSendsEscape =
            try values.decodeIfPresent(Bool.self, forKey: .tapSendsEscape) ?? tapSendsEscape
        excludedKeyboards =
            try values.decodeIfPresent([Keyboard].self, forKey: .excludedKeyboards)
            ?? excludedKeyboards
    }

    public func applies(to keyboard: Keyboard) -> Bool {
        !excludedKeyboards.contains(keyboard)
    }

    public mutating func setApplies(_ applies: Bool, to keyboard: Keyboard) {
        excludedKeyboards.removeAll { $0 == keyboard }
        if !applies {
            excludedKeyboards.append(keyboard)
        }
    }
}
