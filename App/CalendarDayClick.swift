import AppCore

@MainActor
enum CalendarDayClick {
    private static let field = "calendar_day_searches"

    static func searches(in modules: ModuleManager?) -> Bool {
        LauncherSettings.value(field, in: modules) == .bool(true)
    }

    static func setSearches(_ searches: Bool, in modules: ModuleManager?) throws {
        try LauncherSettings.setValue(.bool(searches), for: field, in: modules)
    }
}
