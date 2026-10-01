import AppCore

enum LauncherScreen: String, CaseIterable {
    case activeWindow = "active_window"
    case mouse = "mouse"

    private static let key = "launcher"
    private static let field = "screen"

    var title: String {
        switch self {
        case .activeWindow: "Screen with Active Window"
        case .mouse: "Screen with Mouse"
        }
    }

    @MainActor
    static func load(from modules: ModuleManager?) -> Self {
        guard case .string(let raw) = launcher(modules)[field] else { return .mouse }
        return Self(rawValue: raw) ?? .mouse
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
