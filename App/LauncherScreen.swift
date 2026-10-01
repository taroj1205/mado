enum LauncherScreen: String, LauncherSetting {
    case activeWindow = "active_window"
    case mouse = "mouse"

    static let field = "screen"
    static let fallback = Self.mouse

    var title: String {
        switch self {
        case .activeWindow: "Screen with Active Window"
        case .mouse: "Screen with Mouse"
        }
    }
}
