import AppCore
import AppKit

struct MenuBarAgendaSettings: StoredValue, Equatable {
    static let key = "menu_bar_agenda"

    var isShown: Bool
    var hidesTitles: Bool

    init() {
        isShown = true
        hidesTitles = false
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        isShown = try values.decodeIfPresent(Bool.self, forKey: .isShown) ?? isShown
        hidesTitles = try values.decodeIfPresent(Bool.self, forKey: .hidesTitles) ?? hidesTitles
    }

    @MainActor
    static func section(
        _ modules: ModuleManager?, _ item: MenuBarAgendaItem
    ) -> SettingsSection {
        SettingsSection(
            "Menu Bar",
            [
                .init("Show next event", toggle(\.isShown, in: modules, item: item)),
                .init(
                    "Show event titles",
                    toggle(\.hidesTitles, in: modules, item: item, inverted: true)),
            ])
    }

    @MainActor
    private static func toggle(
        _ field: WritableKeyPath<Self, Bool>, in modules: ModuleManager?, item: MenuBarAgendaItem,
        inverted: Bool = false
    ) -> SettingsSwitch {
        let control = SettingsSwitch(
            read: { load(from: modules)[keyPath: field] != inverted },
            write: { isOn in
                var settings = load(from: modules)
                settings[keyPath: field] = isOn != inverted
                settings.save(to: modules)
                item.refresh()
            })
        control.isEnabled = modules != nil
        return control
    }
}
