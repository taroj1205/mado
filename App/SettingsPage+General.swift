import AppCore
import AppKit

extension SettingsPage {
    static func general(_ context: Context) -> [SettingsSection] {
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
                    .init(
                        "Show in menu bar",
                        SettingsSwitch(
                            read: { context.statusItem?.isVisible == true },
                            write: { context.statusItem?.isVisible = $0 })),
                    .init(
                        "Open when Mado starts",
                        SettingsSwitch(
                            read: { OpenOnLaunch.isEnabled(in: context.modules) },
                            write: { try OpenOnLaunch.setEnabled($0, in: context.modules) })),
                ]),
            SettingsSection(
                "Window",
                [
                    .init("Show on", screenPopUp(context.modules)),
                    .init("Keep last query", popUp(QueryLifetime.self, context.modules)),
                ]),
        ]
    }

    static func hotKeyPopUp(
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

    static func screenPopUp(_ modules: ModuleManager?) -> SettingsPopUp {
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
}
