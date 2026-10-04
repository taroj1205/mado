public import AppCore

public struct InputSourceSettings: Codable, Equatable, Sendable {
    public static let defaultKeys = [
        InputKey(target: .english, hotKey: .modifierTap(.leftCommand)),
        InputKey(target: .japanese, hotKey: .modifierTap(.rightCommand)),
    ]

    public var apps: [String: AppInput]
    public private(set) var keys: [InputKey]

    public init() {
        apps = [:]
        keys = Self.defaultKeys
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        apps = try values.decodeIfPresent([String: AppInput].self, forKey: .apps) ?? apps
        keys = try values.decodeIfPresent([InputKey].self, forKey: .keys) ?? keys
    }

    public func hotKey(for target: InputTarget) -> HotKey? {
        keys.first { $0.target == target }?.hotKey
    }

    public mutating func bind(_ hotKey: HotKey?, to target: InputTarget) {
        let replaced = keys.firstIndex { $0.target == target }
        keys.removeAll { $0.target == target || $0.hotKey == hotKey }
        guard let hotKey else { return }
        keys.insert(
            InputKey(target: target, hotKey: hotKey), at: min(replaced ?? keys.count, keys.count))
    }
}
