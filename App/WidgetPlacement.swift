import GlassUI

enum WidgetPlacement: String, LauncherSetting {
    case above = "floating_above"
    case around = "floating_around"
    case grid = "inline_grid"
    case strip = "inline_strip"

    static let allCases: [Self] = [.grid, .strip, .above, .around]
    static let field = "widget_placement"
    static let fallback = Self.grid

    var title: String {
        switch self {
        case .grid: "Grid"
        case .strip: "Strip"
        case .above: "Above the Panel"
        case .around: "Around the Panel"
        }
    }

    var layout: WidgetGrid.Layout {
        switch self {
        case .grid: .grid
        case .strip: .strip
        case .above: .above
        case .around: .around
        }
    }
}
