import AppCore
import AppKit

struct SwitcherSettings: StoredValue, Equatable {
    enum Order: String, Codable, CaseIterable {
        case byApp = "by_app"
        case recent = "recent"

        var title: String {
            switch self {
            case .byApp: "Grouped by App"
            case .recent: "Most Recent Window"
            }
        }
    }

    enum Swipe: Int, Codable, CaseIterable {
        case off = 0
        case threeFingers = 3
        case fourFingers = 4

        var title: String {
            switch self {
            case .off: "Off"
            case .threeFingers: "Three Fingers"
            case .fourFingers: "Four Fingers"
            }
        }

        var fingers: Int? {
            self == .off ? nil : rawValue
        }
    }

    static let key = "switcher"

    var order: Order
    var swipe: Swipe
    var haptics: Bool

    init() {
        order = .byApp
        swipe = .threeFingers
        haptics = true
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        order = try values.decodeIfPresent(Order.self, forKey: .order) ?? order
        swipe = try values.decodeIfPresent(Swipe.self, forKey: .swipe) ?? swipe
        haptics = try values.decodeIfPresent(Bool.self, forKey: .haptics) ?? haptics
    }

    @MainActor
    static func section(_ modules: ModuleManager?) -> SettingsSection {
        SettingsSection(
            "Window switcher",
            [
                .init("Order", orderPopUp(modules)), .init("Trackpad swipe", swipePopUp(modules)),
                .init("Tap the trackpad as the selection moves", hapticsSwitch(modules)),
            ])
    }

    @MainActor
    private static func hapticsSwitch(_ modules: ModuleManager?) -> SettingsSwitch {
        let toggle = SettingsSwitch(
            read: { load(from: modules).haptics },
            write: { isOn in
                var settings = load(from: modules)
                settings.haptics = isOn
                try modules?.setValue(settings, for: key)
            })
        toggle.isEnabled = modules != nil
        return toggle
    }

    @MainActor
    private static func orderPopUp(_ modules: ModuleManager?) -> SettingsPopUp {
        let popUp = SettingsPopUp {
            let current = load(from: modules)
            let choices = Order.allCases.map { order in
                SettingsPopUp.Choice(title: order.title, isSelected: order == current.order) {
                    var settings = load(from: modules)
                    settings.order = order
                    settings.save(to: modules)
                }
            }
            return [SettingsPopUp.Section(title: nil, choices: choices)]
        }
        popUp.isEnabled = modules != nil
        return popUp
    }

    @MainActor
    private static func swipePopUp(_ modules: ModuleManager?) -> SettingsPopUp {
        let popUp = SettingsPopUp {
            let current = load(from: modules)
            let choices = Swipe.allCases.map { swipe in
                SettingsPopUp.Choice(title: swipe.title, isSelected: swipe == current.swipe) {
                    var settings = load(from: modules)
                    settings.swipe = swipe
                    try modules?.setValue(settings, for: key)
                    try modules?.restart(WindowsModule.id)
                }
            }
            return [SettingsPopUp.Section(title: nil, choices: choices)]
        }
        popUp.isEnabled = modules != nil
        return popUp
    }
}
