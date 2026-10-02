import AppCore
import AppKit
import SearchKit
import WindowKit

@MainActor
struct SettingsPage {
    struct Context {
        let modules: ModuleManager?
        let hotKeys: LauncherHotKeys
        let rates: ExchangeRateFeed
        let recorder: HotKeyPopover
        let apps: AppHotKeys
        let radial: RadialMenuSettings
        let gallery: WidgetGalleryWindow
    }

    struct Tab {
        let title: String
        let sections: ((Context) -> [SettingsSection])?
    }

    static let all: [Self] = [
        Self("General", "gearshape") { context in
            [
                SettingsSection(
                    "Launcher",
                    [
                        .init("Launcher hotkey", hotKeyPopUp(context.hotKeys, context.modules)),
                        .init(
                            "Launch at login",
                            SettingsSwitch(
                                read: { LaunchAtLogin.isEnabled },
                                write: LaunchAtLogin.setEnabled)),
                    ]),
                SettingsSection(
                    "Window",
                    [
                        .init("Show on", screenPopUp(context.modules)),
                        .init("Keep last query", popUp(QueryLifetime.self, context.modules)),
                    ]),
            ]
        },
        Self("Search", "magnifyingglass") { answers($0.modules, $0.rates) },
        Self(
            "Widgets", "square.grid.2x2",
            module: module(Widgets.moduleID, "Widgets", enabled: true)
        ) { context in
            [
                SettingsSection(
                    "Layout",
                    [.init("Placement", popUp(WidgetPlacement.self, context.modules))]),
                SettingsSection(
                    "Gallery",
                    [.init("Widgets on the empty query", galleryButton(context))]),
            ]
        },
        Self(
            "Clipboard", "clipboard",
            module: module("clipboard", "Clipboard history", enabled: true)),
        Self(
            "Windows", "rectangle.split.2x1",
            module: module("windows", "Windows", enabled: true),
            tabs: [
                Tab(title: "Layouts") { context in
                    WindowLayouts.sections(recorder: context.recorder, modules: context.modules)
                },
                Tab(title: "Apps") { [$0.apps.section] },
                Tab(title: "Radial Menu") { $0.radial.sections },
                Tab(title: "Switcher") { context in
                    [
                        SettingsSection(
                            "Window switcher", [.init("Order", orderPopUp(context.modules))])
                    ]
                },
                Tab(title: "Drag & Snap") { context in
                    [
                        SettingsSection(
                            "Gestures",
                            [.init("Move and resize", gestureTargetPopUp(context.modules))])
                    ]
                },
            ]),
        Self("Keyboard", "keyboard", module: module("keyboard", "Keyboard", enabled: true)),
        Self("Voice", "mic", module: module("dictation", "Dictation", enabled: false)),
        Self("AI", "sparkle", module: module("ai", "AI", enabled: false)),
        Self("Notes", "note.text", module: module("notes", "Notes & calendar", enabled: true)),
        Self("Utilities", "bolt", module: module("utilities", "Utilities", enabled: true)),
        Self("Extensions", "storefront"),
        Self("Shortcuts", "command"),
        Self("Permissions", "lock.shield"),
        Self("Advanced", "gearshape.2") { _ in developer },
        Self("About", "person.crop.circle"),
    ]

    private static var developer: [SettingsSection] {
        #if DEBUG
            [
                SettingsSection(
                    "Developer",
                    [
                        .init(
                            "Keep launcher open when focus leaves",
                            SettingsSwitch(
                                read: { KeepLauncherOpen.isEnabled },
                                write: KeepLauncherOpen.setEnabled))
                    ])
            ]
        #else
            []
        #endif
    }

    let title: String
    let symbol: String
    let module: ModuleDescriptor?
    let tabs: [Tab]

    private init(
        _ title: String, _ symbol: String, module: ModuleDescriptor?, tabs: [Tab]
    ) {
        self.title = title
        self.symbol = symbol
        self.module = module
        self.tabs = tabs
    }

    private init(
        _ title: String, _ symbol: String, module: ModuleDescriptor? = nil,
        sections: @escaping (Context) -> [SettingsSection] = { _ in [] }
    ) {
        self.init(title, symbol, module: module, tabs: [Tab(title: title, sections: sections)])
    }

    private static func popUp<Setting: LauncherSetting>(
        _: Setting.Type, _ modules: ModuleManager?
    ) -> SettingsPopUp {
        let popUp = SettingsPopUp {
            let current = Setting.load(from: modules)
            let choices = Setting.allCases.map { choice in
                SettingsPopUp.Choice(title: choice.title, isSelected: choice == current) {
                    try choice.save(to: modules)
                }
            }
            return [SettingsPopUp.Section(title: nil, choices: choices)]
        }
        popUp.isEnabled = modules != nil
        return popUp
    }

    private static func galleryButton(_ context: Context) -> SettingsButton {
        let button = SettingsButton("Add Widgets…") { context.gallery.show() }
        button.isEnabled = context.modules != nil
        return button
    }

    private static func orderPopUp(_ modules: ModuleManager?) -> SettingsPopUp {
        let popUp = SettingsPopUp {
            let current = SwitcherSettings.load(from: modules)
            let choices = SwitcherSettings.Order.allCases.map { order in
                SettingsPopUp.Choice(title: order.title, isSelected: order == current.order) {
                    var settings = SwitcherSettings.load(from: modules)
                    settings.order = order
                    settings.save(to: modules)
                }
            }
            return [SettingsPopUp.Section(title: nil, choices: choices)]
        }
        popUp.isEnabled = modules != nil
        return popUp
    }

    private static func gestureTargetPopUp(_ modules: ModuleManager?) -> SettingsPopUp {
        let popUp = SettingsPopUp {
            let current = GestureSettings.load(from: modules)
            let choices = GestureSettings.Target.allCases.map { target in
                SettingsPopUp.Choice(title: target.title, isSelected: target == current.target) {
                    var settings = GestureSettings.load(from: modules)
                    settings.target = target
                    settings.save(to: modules)
                }
            }
            return [SettingsPopUp.Section(title: nil, choices: choices)]
        }
        popUp.isEnabled = modules != nil
        return popUp
    }

    private static func hotKeyPopUp(
        _ hotKeys: LauncherHotKeys, _ modules: ModuleManager?
    ) -> SettingsPopUp {
        let popUp = SettingsPopUp {
            let current = hotKeys.key
            let choices = LauncherHotKeys.Key.allCases.map { key in
                SettingsPopUp.Choice(title: key.title, isSelected: key == current) {
                    try hotKeys.use(key)
                }
            }
            return [SettingsPopUp.Section(title: nil, choices: choices)]
        }
        popUp.isEnabled = modules != nil
        return popUp
    }

    private static func screenPopUp(_ modules: ModuleManager?) -> SettingsPopUp {
        let popUp = SettingsPopUp {
            let current = LauncherScreen.load(from: modules)
            let choice = { (screen: LauncherScreen) in
                SettingsPopUp.Choice(
                    title: screen.title, isSelected: screen.id == current.id,
                    isEnabled: screen.isAvailable
                ) { try screen.save(to: modules) }
            }
            return [
                SettingsPopUp.Section(
                    title: nil, choices: [choice(.mouse), choice(.activeWindow)]),
                SettingsPopUp.Section(
                    title: "Displays",
                    choices: LauncherScreen.displays(keeping: current).map(choice)),
            ]
        }
        popUp.isEnabled = modules != nil
        return popUp
    }

    private static func module(_ id: String, _ name: String, enabled: Bool) -> ModuleDescriptor {
        ModuleDescriptor(id: id, name: name, enabledByDefault: enabled, hasSettingsPage: true)
    }
}
