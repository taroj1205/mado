public struct EnterGuardSettings: Codable, Equatable, Sendable {
    public struct BuiltIn: Sendable {
        public let name: String
        public let bundleIDs: [String]
    }

    private enum CodingKeys: String, CodingKey {
        case isOn = "on"
        case addedApps = "added_apps"
        case appsOff = "apps_off"
    }

    public static let builtIns = [
        BuiltIn(name: "Claude", bundleIDs: ["com.anthropic.claudefordesktop"]),
        BuiltIn(name: "ChatGPT", bundleIDs: ["com.openai.chat", "com.openai.codex"]),
        BuiltIn(name: "Cursor", bundleIDs: ["com.todesktop.230313mzl4w4u92"]),
        BuiltIn(name: "Gemini", bundleIDs: ["com.google.GeminiMacOS"]),
        BuiltIn(name: "Perplexity", bundleIDs: ["ai.perplexity.macv3"]),
    ]

    public var isOn: Bool
    public private(set) var addedApps: [String]
    private var appsOff: [String]

    public init() {
        isOn = true
        addedApps = []
        appsOff = []
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        isOn = try values.decodeIfPresent(Bool.self, forKey: .isOn) ?? isOn
        addedApps = try values.decodeIfPresent([String].self, forKey: .addedApps) ?? addedApps
        appsOff = try values.decodeIfPresent([String].self, forKey: .appsOff) ?? appsOff
    }

    private static func builtIn(_ app: String) -> BuiltIn? {
        builtIns.first { $0.bundleIDs.contains(app) }
    }

    public func guards(_ app: String?) -> Bool {
        guard let app, !appsOff.contains(app) else { return false }
        return Self.builtIn(app) != nil || addedApps.contains(app)
    }

    public mutating func setGuarding(_ apps: [String], _ isGuarding: Bool) {
        appsOff.removeAll(where: apps.contains)
        if !isGuarding {
            appsOff += apps
        }
    }

    public mutating func add(_ app: String) {
        if let builtIn = Self.builtIn(app) {
            setGuarding(builtIn.bundleIDs, true)
            return
        }
        if !addedApps.contains(app) {
            addedApps.append(app)
        }
        setGuarding([app], true)
    }
}
