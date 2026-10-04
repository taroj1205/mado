import AppCore

protocol LauncherSetting: RawRepresentable<String>, CaseIterable, Equatable {
    static var field: String { get }
    static var legacyField: String? { get }
    static var fallback: Self { get }
    var title: String { get }
}

extension LauncherSetting {
    static var legacyField: String? { nil }

    @MainActor
    static func load(from modules: ModuleManager?) -> Self {
        let value =
            LauncherSettings.value(field, in: modules)
            ?? legacyField.flatMap { LauncherSettings.value($0, in: modules) }
        guard case .string(let raw) = value else {
            return fallback
        }
        return Self(rawValue: raw) ?? fallback
    }

    @MainActor
    func save(to modules: ModuleManager?) throws {
        try LauncherSettings.setValue(.string(rawValue), for: Self.field, in: modules)
    }
}
