import AppCore
import AppKit
import GlassUI

@MainActor
struct LyricsSettingsEditor {
    typealias Change = @MainActor () -> Void

    private static let playerGap: CGFloat = 14
    private static let looks: [(look: LyricsLook, title: String)] = [
        (.line, "Line"), (.card, "Card"), (.lyrics, "Lyrics"),
    ]
    private static let players: [(player: MusicPlayer.Player, title: String)] = [
        (.music, "Music"), (.spotify, "Spotify"),
    ]

    let modules: ModuleManager?
    let changed: Change

    private var current: LyricsSettings {
        .load(from: modules)
    }

    func edit(_ change: (inout LyricsSettings) -> Void) {
        var settings = current
        change(&settings)
        settings.save(to: modules)
        changed()
    }

    func toggle(_ path: WritableKeyPath<LyricsSettings, Bool>) -> SettingsSwitch {
        let control = SettingsSwitch(
            read: { current[keyPath: path] },
            write: { isOn in edit { settings in settings[keyPath: path] = isOn } })
        control.isEnabled = modules != nil
        return control
    }

    func spotPicker() -> LyricsSpotPicker {
        let picker = LyricsSpotPicker(
            read: { current.spot },
            write: { spot in
                edit { settings in
                    if let spot { settings.place(at: spot) } else { settings.pin = nil }
                }
            })
        picker.isEnabled = modules != nil
        return picker
    }

    func pinPopUp(then picked: @escaping () -> Void) -> SettingsPopUp {
        popUp {
            let choice = { (pin: LyricsPin?) in
                SettingsPopUp.Choice(title: pin?.title ?? "Off", isSelected: pin == current.pin) {
                    edit { settings in settings.pin = pin }
                    picked()
                }
            }
            return [
                SettingsPopUp.Section(
                    title: nil, choices: [choice(nil)] + LyricsPin.allCases.map(choice))
            ]
        }
    }

    func sizeControl() -> SettingsSegments {
        let control = SettingsSegments(
            Self.looks.map(\.title),
            read: { Self.looks.firstIndex { $0.look == current.look } ?? 0 },
            write: { index in edit { settings in settings.look = Self.looks[index].look } })
        control.isEnabled = modules != nil
        return control
    }

    func screenPopUp() -> SettingsPopUp {
        popUp {
            let choice = { (screen: LauncherScreen) in
                SettingsPopUp.Choice(
                    title: screen.title, isSelected: screen.id == current.screen.id,
                    isEnabled: screen.isAvailable
                ) { edit { settings in settings.screen = screen } }
            }
            return [
                SettingsPopUp.Section(
                    title: nil, choices: [choice(.mouse), choice(.activeWindow)]),
                SettingsPopUp.Section(
                    title: "Displays",
                    choices: LauncherScreen.displays(keeping: current.screen).map(choice)),
            ]
        }
    }

    func hidePopUp() -> SettingsPopUp {
        popUp {
            let choices = LyricsSettings.HideDelay.allCases.map { delay in
                SettingsPopUp.Choice(
                    title: delay.title, isSelected: delay == current.hideDelay
                ) { edit { settings in settings.hideDelay = delay } }
            }
            return [SettingsPopUp.Section(title: nil, choices: choices)]
        }
    }

    func playerChecks() -> NSStackView {
        let checks = Self.players.map { entry in
            let check = SettingsCheckbox(
                entry.title, read: { current.players.contains(entry.player) },
                write: { isOn in
                    edit { settings in
                        if isOn {
                            settings.players.insert(entry.player)
                        } else {
                            settings.players.remove(entry.player)
                        }
                    }
                })
            check.isEnabled = modules != nil
            return check
        }
        let stack = NSStackView(views: checks)
        stack.spacing = Self.playerGap
        return stack
    }

    private func popUp(_ sections: @escaping () -> [SettingsPopUp.Section]) -> SettingsPopUp {
        let control = SettingsPopUp(sections)
        control.isEnabled = modules != nil
        return control
    }
}
