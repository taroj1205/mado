public enum LyricsPin: String, CaseIterable, Sendable {
    case corner = "corner_card"
    case desktop = "desktop_type"
    case dock = "dock_gap"
    case island = "island"
    case menuBar = "menu_bar_line"
    case menus = "menu_bar_left"

    public static let allCases: [Self] = [.island, .corner, .menuBar, .desktop, .dock, .menus]

    public var title: String {
        switch self {
        case .corner: "Corner card"
        case .desktop: "Desktop type"
        case .dock: "Next to the Dock"
        case .island: "Island"
        case .menuBar: "Menu bar line"
        case .menus: "Next to the menus"
        }
    }
}
