public struct InputSourceSettings: Codable, Equatable, Sendable {
    public var apps: [String: AppInput]

    public init() {
        apps = [:]
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        apps = try values.decodeIfPresent([String: AppInput].self, forKey: .apps) ?? apps
    }
}
