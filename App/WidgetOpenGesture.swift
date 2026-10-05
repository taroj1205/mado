enum WidgetOpenGesture: String, LauncherSetting {
    case doubleClick = "double_click"
    case singleClick = "single_click"

    static let allCases: [Self] = [.doubleClick, .singleClick]
    static let field = "widget_open_gesture"
    static let fallback = Self.doubleClick

    var title: String {
        switch self {
        case .doubleClick: "Double-click"
        case .singleClick: "Click"
        }
    }
}
