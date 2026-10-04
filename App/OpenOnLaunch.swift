import AppCore

@MainActor
enum OpenOnLaunch {
    private static let field = "open_on_launch"

    static func isEnabled(in modules: ModuleManager?) -> Bool {
        LauncherSettings.value(field, in: modules) == .bool(true)
    }

    static func setEnabled(_ enabled: Bool, in modules: ModuleManager?) throws {
        try LauncherSettings.setValue(.bool(enabled), for: field, in: modules)
    }
}
