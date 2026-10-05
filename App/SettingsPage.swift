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
        let clipboardHistory: ClipboardHistorySettings
        let ignoredApps: AppListSettings
        let withoutExpansion: AppListSettings
        let inputKeys: InputSourceKeys
        let inputDefaults: AppInputDefaults
        let remaps: RemapsSettings
        let enterGuard: EnterGuardPage
        let addWidgets: @MainActor () -> Void
        let speechModels: SpeechModelSettings
        let colourKeys: ColourPickerKeysPage
        let statusItem: NSStatusItem?
    }

    struct Tab {
        let title: String
        let sections: ((Context) -> [SettingsSection])?
    }

    static let all: [Self] = [
        Self("General", "gearshape") { general($0) },
        Self("Search", "magnifyingglass") { answers($0.modules, $0.rates) },
        Self(
            "Widgets", "square.grid.2x2",
            module: module(Widgets.moduleID, "Widgets", enabled: true)
        ) { context in
            [
                SettingsSection(
                    "Layout",
                    [
                        .init("Placement", popUp(WidgetPlacement.self, context.modules)),
                        .init("Inside the panel", popUp(WidgetInlineStyle.self, context.modules)),
                    ]),
                SettingsSection(
                    "Mouse",
                    [.init("Open a widget with", popUp(WidgetOpenGesture.self, context.modules))]),
                SettingsSection(
                    "Gallery",
                    [.init("Widgets on the empty query", galleryButton(context))]),
                WeatherSettings.section(context.modules),
            ]
        },
        Self(
            "Clipboard", "clipboard",
            module: module("clipboard", "Clipboard history", enabled: true)
        ) { context in
            let hotkey = context.recorder.button(
                for: ClipboardHistory.commandID, named: "Open history")
            var history = context.clipboardHistory.section
            history.rows.insert(.init("Open history", hotkey), at: 0)
            return [
                history, context.ignoredApps.section, context.clipboardHistory.clearSection,
                context.withoutExpansion.section,
            ]
        },
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
                        SwitcherSettings.section(context.modules)
                    ]
                },
                Tab(title: "Drag & Snap") { context in
                    [
                        SettingsSection(
                            "Gestures",
                            [
                                .init("Hold to move", WindowTrigger.move.button(context.modules)),
                                .init(
                                    "Hold to resize", WindowTrigger.resize.button(context.modules)),
                                .init("Move and resize", gestureTargetPopUp(context.modules)),
                            ], footer: WindowTrigger.footer, accessory: nil)
                    ]
                },
            ]),
        Self(
            "Keyboard", "keyboard",
            module: module("keyboard", "Keyboard", enabled: true),
            tabs: [
                Tab(title: "Modifier Keys", sections: nil),
                Tab(title: "Input Sources") { $0.inputKeys.sections + [$0.inputDefaults.section] },
                Tab(title: "Enter Guard") { $0.enterGuard.sections },
                Tab(title: "Remaps") { $0.remaps.sections },
            ]),
        Self("Voice", "mic", module: module("dictation", "Dictation", enabled: false)) { context in
            [SettingsSection("Dictation", []), context.speechModels.section]
        },
        Self("AI", "sparkle", module: module("ai", "AI", enabled: false)),
        Self("Notes", "note.text", module: module("notes", "Notes & calendar", enabled: true)),
        Self(
            "Utilities", "bolt", module: module("utilities", "Utilities", enabled: true)
        ) { context in context.colourKeys.sections },
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

    static func popUp<Setting: LauncherSetting>(
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
        let button = SettingsButton("Add Widgets…") { context.addWidgets() }
        button.isEnabled = context.modules != nil
        return button
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

    private static func module(_ id: String, _ name: String, enabled: Bool) -> ModuleDescriptor {
        ModuleDescriptor(id: id, name: name, enabledByDefault: enabled, hasSettingsPage: true)
    }
}
