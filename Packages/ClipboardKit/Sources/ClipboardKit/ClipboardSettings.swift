public struct ClipboardSettings: Codable, Equatable, Sendable {
    private enum CodingKeys: CodingKey {
        case retention
        case assignedDefaultHotKey
        case addedApps
        case removedApps
    }

    public static let defaultIgnoredApps: KeyValuePairs<String, String> = [
        "com.1password.1password": "Password manager",
        "com.bitwarden.desktop": "Password manager",
        "org.keepassxc.keepassxc": "Password manager",
        "com.apple.Passwords": "System",
        "com.apple.keychainaccess": "System",
    ]

    public var retention: ClipboardStore.Retention
    public var assignedDefaultHotKey: Bool
    private var ignored: AppList

    public var ignoredApps: [String] {
        ignored.apps
    }

    public init() {
        retention = ClipboardStore.Retention()
        assignedDefaultHotKey = false
        ignored = AppList(defaults: Self.defaultIgnoredApps.map(\.key))
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        retention =
            try values.decodeIfPresent(ClipboardStore.Retention.self, forKey: .retention)
            ?? retention
        assignedDefaultHotKey =
            try values.decodeIfPresent(Bool.self, forKey: .assignedDefaultHotKey)
            ?? assignedDefaultHotKey
        ignored = try AppList(
            defaults: Self.defaultIgnoredApps.map(\.key), from: values, added: .addedApps,
            removed: .removedApps)
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(retention, forKey: .retention)
        try values.encode(assignedDefaultHotKey, forKey: .assignedDefaultHotKey)
        try ignored.encode(to: &values, added: .addedApps, removed: .removedApps)
    }

    public func ignores(any apps: [String]) -> Bool {
        apps.contains(where: ignored.contains)
    }

    public mutating func ignore(_ app: String) {
        ignored.add(app)
    }

    public mutating func stopIgnoring(_ app: String) {
        ignored.remove(app)
    }
}
