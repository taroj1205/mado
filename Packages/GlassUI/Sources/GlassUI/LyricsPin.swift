public enum LyricsPin: String, CaseIterable, Sendable {
    case corner = "corner_card"
    case desktop = "desktop_type"
    case island = "island"
    case menuBar = "menu_bar_line"

    public static let allCases: [Self] = [.island, .corner, .menuBar, .desktop]

    public var title: String {
        switch self {
        case .corner: "Corner card"
        case .desktop: "Desktop type"
        case .island: "Island"
        case .menuBar: "Menu bar line"
        }
    }
}
