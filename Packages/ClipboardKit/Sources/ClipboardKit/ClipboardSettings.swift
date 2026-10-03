public struct ClipboardSettings: Codable, Equatable, Sendable {
    public static let defaultIgnoredApps: KeyValuePairs<String, String> = [
        "com.1password.1password": "Password manager",
        "com.bitwarden.desktop": "Password manager",
        "org.keepassxc.keepassxc": "Password manager",
        "com.apple.Passwords": "System",
        "com.apple.keychainaccess": "System",
    ]

    public var retention: ClipboardStore.Retention
    private var addedApps: [String]
    private var removedApps: [String]

    public var ignoredApps: [String] {
        (Self.defaultIgnoredApps.map(\.key) + addedApps).filter { !removedApps.contains($0) }
    }

    public init() {
        retention = ClipboardStore.Retention()
        addedApps = []
        removedApps = []
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        addedApps = try values.decodeIfPresent([String].self, forKey: .addedApps) ?? addedApps
        removedApps =
            try values.decodeIfPresent([String].self, forKey: .removedApps) ?? removedApps
        let saved = try values.decodeIfPresent(ClipboardStore.Retention.self, forKey: .retention)
        if let saved, saved.days > 0, saved.items > 0 {
            retention = saved
        }
    }

    public func ignores(any apps: [String]) -> Bool {
        apps.contains(where: ignoredApps.contains)
    }

    public mutating func ignore(_ app: String) {
        removedApps.removeAll { $0 == app }
        if !ignoredApps.contains(app) {
            addedApps.append(app)
        }
    }

    public mutating func stopIgnoring(_ app: String) {
        addedApps.removeAll { $0 == app }
        if ignoredApps.contains(app) {
            removedApps.append(app)
        }
    }
}
