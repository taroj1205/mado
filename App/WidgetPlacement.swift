import GlassUI

enum WidgetPlacement: String, LauncherSetting {
    case above = "floating_above"
    case around = "floating_around"
    case custom = "custom"
    case inPanel = "in_panel"

    static let allCases: [Self] = [.inPanel, .above, .around, .custom]
    static let field = "widget_placement"
    static let fallback = Self.inPanel

    var title: String {
        switch self {
        case .inPanel: "In the Panel"
        case .above: "Above"
        case .around: "Around"
        case .custom: "Custom"
        }
    }

    var arrangement: WidgetSettings.Arrangement {
        switch self {
        case .inPanel: .inPanel
        case .above: .above
        case .around: .around
        case .custom: .custom
        }
    }
}
