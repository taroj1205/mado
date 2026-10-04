public import AppCore
import IOKit.hid

public struct RemapSettings: Codable, Equatable, Sendable {
    public enum CapsLock: String, Codable, CaseIterable, Sendable {
        case capsLock = "caps_lock"
        case control = "control"
        case escape = "escape"
        case hyper = "hyper"

        public var isModifier: Bool {
            [.control, .hyper].contains(self)
        }
    }

    public enum TapAction: String, Codable, CaseIterable, Sendable {
        case nothing = "nothing"
        case escape = "escape"
        case capsLock = "caps_lock"
        case openMado = "open_mado"
        case shortcut = "shortcut"
    }

    private enum LegacyKeys: String, CodingKey {
        case sendsEscape = "tapSendsEscape"
    }

    public var capsLock: CapsLock
    public var tapAction: TapAction
    public var tapShortcut: Shortcut?
    public var hyperAsGlyph: Bool
    public var excludedKeyboards: [Keyboard]

    public var tap: CapsLockTap? {
        guard capsLock.isModifier else { return nil }
        switch tapAction {
        case .nothing: return nil
        case .escape: return .escape
        case .capsLock: return .capsLock
        case .openMado: return .openMado
        case .shortcut: return tapShortcut.map(CapsLockTap.shortcut)
        }
    }

    var usage: UInt64? {
        let control = tap == nil ? kHIDUsage_KeyboardLeftControl : kHIDUsage_KeyboardRightControl
        switch capsLock {
        case .capsLock: return nil
        case .control: return KeyMappings.usage(control)
        case .escape: return KeyMappings.usage(kHIDUsage_KeyboardEscape)
        case .hyper: return KeyMappings.usage(kHIDUsage_KeyboardF18)
        }
    }

    var mappings: KeyMappings? {
        guard let usage else { return nil }
        let rightControl = KeyMappings.usage(kHIDUsage_KeyboardRightControl)
        let leftControl = KeyMappings.usage(kHIDUsage_KeyboardLeftControl)
        let others = usage == rightControl ? [KeyMappings.entry(rightControl, to: leftControl)] : []
        return KeyMappings(
            remapped: [KeyMappings.entry(KeyMappings.capsLock, to: usage)] + others, others: others)
    }

    public var showsHyperGlyph: Bool {
        hyperAsGlyph && capsLock == .hyper
    }

    public init() {
        capsLock = .capsLock
        tapAction = .nothing
        tapShortcut = nil
        hyperAsGlyph = false
        excludedKeyboards = []
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        self.init()
        capsLock = try values.decodeIfPresent(CapsLock.self, forKey: .capsLock) ?? capsLock
        let sendsEscape = try legacy.decodeIfPresent(Bool.self, forKey: .sendsEscape) == true
        tapAction =
            try values.decodeIfPresent(TapAction.self, forKey: .tapAction)
            ?? (sendsEscape ? .escape : tapAction)
        tapShortcut = try values.decodeIfPresent(Shortcut.self, forKey: .tapShortcut)
        hyperAsGlyph =
            try values.decodeIfPresent(Bool.self, forKey: .hyperAsGlyph) ?? hyperAsGlyph
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
