import AppCore

struct LauncherSettings: Codable {
    enum Screen: String, Codable, CaseIterable {
        case mouse = "mouse"
        case activeWindow = "active_window"

        var title: String {
            switch self {
            case .mouse: "Screen with Mouse"
            case .activeWindow: "Screen with Active Window"
            }
        }
    }

    private static let key = "launcher"

    var screen = Screen.mouse

    @MainActor
    static func load(from modules: ModuleManager?) -> Self {
        (try? modules?.value(Self.self, for: key)) ?? Self()
    }

    @MainActor
    func save(to modules: ModuleManager?) throws {
        try modules?.setValue(self, for: Self.key)
    }
}
