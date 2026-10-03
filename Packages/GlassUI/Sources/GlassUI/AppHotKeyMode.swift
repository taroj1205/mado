public import AppKit

public enum AppHotKeyMode: CaseIterable, Sendable {
    case quickPeek
    case toggle

    public final class Menu: NSPopUpButton {
        public var onChange: ((AppHotKeyMode) -> Void)?

        public var selected: AppHotKeyMode {
            get { AppHotKeyMode.allCases[max(indexOfSelectedItem, 0)] }
            set { selectItem(at: AppHotKeyMode.allCases.firstIndex(of: newValue) ?? 0) }
        }

        public init() {
            super.init(frame: .zero, pullsDown: false)
            addItems(withTitles: AppHotKeyMode.allCases.map(\.title))
            target = self
            action = #selector(changed)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        @objc
        private func changed() {
            onChange?(selected)
        }
    }

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
}
