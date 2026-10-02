import GlassUI

enum WidgetPlacement: String, LauncherSetting {
    case grid = "inline_grid"
    case strip = "inline_strip"

    static let field = "widget_placement"
    static let fallback = Self.grid

    var title: String {
        switch self {
        case .grid: "Grid"
        case .strip: "Strip"
        }
    }

    var layout: WidgetGrid.Layout {
        switch self {
        case .grid: .grid
        case .strip: .strip
        }
    }
}
