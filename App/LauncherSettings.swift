import AppCore

@MainActor
enum LauncherSettings {
    private static let key = "launcher"

    static func value(_ field: String, in modules: ModuleManager?) -> JSONValue? {
        values(modules)[field]
    }

    static func setValue(_ value: JSONValue, for field: String, in modules: ModuleManager?) throws {
        var values = values(modules)
        values[field] = value
        try modules?.setValue(values, for: key)
    }

    private static func values(_ modules: ModuleManager?) -> [String: JSONValue] {
        (try? modules?.value([String: JSONValue].self, for: key)) ?? [:]
    }
}
