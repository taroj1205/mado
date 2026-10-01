import AppCore
import AppKit

@MainActor
struct SettingsPage {
    static let all: [Self] = [
        Self("General", "gearshape") { modules in
            [
                SettingsSection(
                    "Launcher",
                    [
                        .init(
                            "Launch at login",
                            SettingsSwitch(
                                read: { LaunchAtLogin.isEnabled },
                                write: LaunchAtLogin.setEnabled))
                    ]),
                SettingsSection("Window", [.init("Show on", screenPopUp(modules))]),
            ]
        },
        Self("Search", "magnifyingglass"),
        Self("Widgets", "square.grid.2x2", module: module("widgets", "Widgets", enabled: true)),
        Self(
            "Clipboard", "clipboard",
            module: module("clipboard", "Clipboard history", enabled: true)),
        Self("Windows", "rectangle.split.2x1", module: module("windows", "Windows", enabled: true)),
        Self("Keyboard", "keyboard", module: module("keyboard", "Keyboard", enabled: true)),
        Self("Voice", "mic", module: module("dictation", "Dictation", enabled: false)),
        Self("AI", "sparkle", module: module("ai", "AI", enabled: false)),
        Self("Notes", "note.text", module: module("notes", "Notes & calendar", enabled: true)),
        Self("Utilities", "bolt", module: module("utilities", "Utilities", enabled: true)),
        Self("Extensions", "storefront"),
        Self("Shortcuts", "command"),
        Self("Permissions", "lock.shield"),
        Self("Advanced", "gearshape.2"),
        Self("About", "person.crop.circle"),
    ]

    let title: String
    let symbol: String
    let module: ModuleDescriptor?
    let sections: (ModuleManager?) -> [SettingsSection]

    private init(
        _ title: String, _ symbol: String, module: ModuleDescriptor? = nil,
        sections: @escaping (ModuleManager?) -> [SettingsSection] = { _ in [] }
    ) {
        self.title = title
        self.symbol = symbol
        self.module = module
        self.sections = sections
    }

    private static func screenPopUp(_ modules: ModuleManager?) -> SettingsPopUp {
        let screens = LauncherScreen.allCases
        let popUp = SettingsPopUp(
            screens.map(\.title),
            read: { screens.firstIndex(of: LauncherScreen.load(from: modules)) ?? 0 },
            write: { try screens[$0].save(to: modules) })
        popUp.isEnabled = modules != nil
        return popUp
    }

    private static func module(_ id: String, _ name: String, enabled: Bool) -> ModuleDescriptor {
        ModuleDescriptor(id: id, name: name, enabledByDefault: enabled, hasSettingsPage: true)
    }
}
