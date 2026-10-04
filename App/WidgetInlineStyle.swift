import GlassUI

enum WidgetInlineStyle: String, LauncherSetting {
    case grid = "inline_grid"
    case strip = "inline_strip"

    static let allCases: [Self] = [.grid, .strip]
    static let field = "widget_inline_style"
    static let legacyField: String? = WidgetPlacement.field
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
