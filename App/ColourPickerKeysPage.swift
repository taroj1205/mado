import AppCore
import AppKit
import GlassUI

@MainActor
final class ColourPickerKeysPage {
    private let modules: ModuleManager?
    private weak var editor: LoupeKeysEditor?
    private weak var popUp: SettingsPopUp?

    var sections: [SettingsSection] {
        let keysEditor = LoupeKeysEditor()
        keysEditor.keys = ColourPickerSettings.load(from: modules).keys
        keysEditor.onChange = { [weak self] in self?.save($0) }
        editor = keysEditor
        let presets = SettingsPopUp { [weak self] in self?.choices() ?? [] }
        presets.isEnabled = modules != nil
        popUp = presets
        return [
            SettingsSection("Colour picker", [.init("Nudge keys", presets)]),
            SettingsSection(content: keysEditor),
        ]
    }

    init(modules: ModuleManager?) {
        self.modules = modules
    }

    private func choices() -> [SettingsPopUp.Section] {
        let current = ColourPickerSettings.load(from: modules).keys
        let select = { [weak self] (preset: LoupeKeys.Preset?) in
            self?.apply(current, choosing: preset)
        }
        var choices = LoupeKeys.Preset.allCases.map { preset in
            SettingsPopUp.Choice(title: preset.title, isSelected: preset == current.preset) {
                select(preset)
            }
        }
        if current.preset == nil {
            choices.append(.init(title: "Custom", isSelected: true) { select(nil) })
        }
        return [SettingsPopUp.Section(title: nil, choices: choices)]
    }

    private func apply(_ current: LoupeKeys, choosing preset: LoupeKeys.Preset? = nil) {
        var keys = current
        if let preset {
            keys.choose(preset)
        }
        save(keys)
        editor?.keys = keys
    }

    private func save(_ keys: LoupeKeys) {
        var settings = ColourPickerSettings.load(from: modules)
        settings.keys = keys
        settings.save(to: modules)
        popUp?.refresh()
    }
}
