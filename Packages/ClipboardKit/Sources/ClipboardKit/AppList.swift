struct AppList: Equatable, Sendable {
    private let defaults: [String]
    private var added: [String] = []
    private var removed: [String] = []

    var apps: [String] {
        (defaults + added).filter { !removed.contains($0) }
    }

    init(defaults: [String]) {
        self.defaults = defaults
    }

    init<Key: CodingKey>(
        defaults: [String], from values: KeyedDecodingContainer<Key>, added: Key, removed: Key
    ) throws {
        self.defaults = defaults
        self.added = try values.decodeIfPresent([String].self, forKey: added) ?? []
        self.removed = try values.decodeIfPresent([String].self, forKey: removed) ?? []
    }

    func encode<Key: CodingKey>(
        to values: inout KeyedEncodingContainer<Key>, added: Key, removed: Key
    ) throws {
        try values.encode(self.added, forKey: added)
        try values.encode(self.removed, forKey: removed)
    }

    func contains(_ app: String) -> Bool {
        apps.contains(app)
    }

    mutating func add(_ app: String) {
        removed.removeAll { $0 == app }
        if !apps.contains(app) {
            added.append(app)
        }
    }

    mutating func remove(_ app: String) {
        added.removeAll { $0 == app }
        if apps.contains(app) {
            removed.append(app)
        }
    }
}
