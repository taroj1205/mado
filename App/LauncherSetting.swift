import AppCore

protocol LauncherSetting: RawRepresentable<String>, CaseIterable, Equatable {
    static var field: String { get }
    static var fallback: Self { get }
    var title: String { get }
}

extension LauncherSetting {
    private static var key: String { "launcher" }

    @MainActor
    static func load(from modules: ModuleManager?) -> Self {
        guard case .string(let raw) = launcher(modules)[field] else { return fallback }
        return Self(rawValue: raw) ?? fallback
    }

    @MainActor
    private static func launcher(_ modules: ModuleManager?) -> [String: JSONValue] {
        (try? modules?.value([String: JSONValue].self, for: key)) ?? [:]
    }

    @MainActor
    func save(to modules: ModuleManager?) throws {
        var launcher = Self.launcher(modules)
        launcher[Self.field] = .string(rawValue)
        try modules?.setValue(launcher, for: Self.key)
    }
}
