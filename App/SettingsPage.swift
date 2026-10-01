import AppCore

@MainActor
struct SettingsPage {
    static let all: [Self] = [
        Self("General", "gearshape") {
            [
                SettingsSection(
                    "Launcher",
                    [
                        .init(
                            "Launch at login",
                            SettingsSwitch(
                                read: { LaunchAtLogin.isEnabled },
                                write: LaunchAtLogin.setEnabled))
                    ])
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
    let sections: () -> [SettingsSection]

    private init(
        _ title: String, _ symbol: String, module: ModuleDescriptor? = nil,
        sections: @escaping () -> [SettingsSection] = { [] }
    ) {
        self.title = title
        self.symbol = symbol
        self.module = module
        self.sections = sections
    }

    private static func module(_ id: String, _ name: String, enabled: Bool) -> ModuleDescriptor {
        ModuleDescriptor(id: id, name: name, enabledByDefault: enabled, hasSettingsPage: true)
    }
}
