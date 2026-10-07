import AppCore

@MainActor
enum OutsideWidgetsWhileSearching {
    private static let field = "outside_widgets_stay_while_searching"

    static func stays(in modules: ModuleManager?) -> Bool {
        LauncherSettings.value(field, in: modules) == .bool(true)
    }

    static func setStays(_ stays: Bool, in modules: ModuleManager?) throws {
        try LauncherSettings.setValue(.bool(stays), for: field, in: modules)
    }
}
