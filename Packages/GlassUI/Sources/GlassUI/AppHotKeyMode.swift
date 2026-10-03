import AppKit

public enum AppHotKeyMode: CaseIterable, Sendable {
    case quickPeek
    case toggle

    public static let allCases: [Self] = [.toggle, .quickPeek]

    public var title: String {
        switch self {
        case .toggle: "Toggle"
        case .quickPeek: "Quick Peek"
        }
    }

    public var summary: String {
        switch self {
        case .toggle: ": launch if closed → bring to front → hide if already in front."
        case .quickPeek: ": the app hides itself again when you switch away."
        }
    }

    public init(quickPeek: Bool) {
        self = quickPeek ? .quickPeek : .toggle
    }

    @MainActor
    init(selectedIn menu: NSPopUpButton) {
        self =
            Self.allCases.indices.contains(menu.indexOfSelectedItem)
            ? Self.allCases[menu.indexOfSelectedItem] : .toggle
    }

    @MainActor
    static func menu() -> NSPopUpButton {
        let menu = NSPopUpButton(frame: .zero, pullsDown: false)
        menu.addItems(withTitles: allCases.map(\.title))
        return menu
    }

    @MainActor
    func select(in menu: NSPopUpButton) {
        menu.selectItem(at: Self.allCases.firstIndex(of: self) ?? 0)
    }
}
