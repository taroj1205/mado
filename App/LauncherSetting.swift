import AppCore

protocol LauncherSetting: RawRepresentable<String>, CaseIterable, Equatable {
    static var field: String { get }
    static var fallback: Self { get }
    var title: String { get }
}

extension LauncherSetting {
    @MainActor
    static func load(from modules: ModuleManager?) -> Self {
        guard case .string(let raw) = LauncherSettings.value(field, in: modules) else {
            return fallback
        }
        return Self(rawValue: raw) ?? fallback
    }

    @MainActor
    func save(to modules: ModuleManager?) throws {
        try LauncherSettings.setValue(.string(rawValue), for: Self.field, in: modules)
    }
}
