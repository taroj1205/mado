import AppCore
import AppKit
import GlassUI
import os
import WindowKit

@MainActor
final class RadialMenuSettings: NSObject {
    private static let origins: [(origin: RadialSettings.Origin, title: String)] = [
        (.pointer, "At pointer"), (.screenCentre, "Screen centre"),
    ]
    private static let toggles: [(option: WritableKeyPath<RadialSettings, Bool>, title: String)] =
        [
            (\.showsPreview, "Show where the window will land while choosing"),
            (\.showsLabel, "Show the action name under the ring"),
            (\.clickStepsCycle, "Left-click while holding steps through a cycle"),
            (\.haptics, "Tap the trackpad when the choice changes"),
        ]
    private static let slots:
        [RadialEditor.Slot: WritableKeyPath<RadialSettings, RadialSettings.Action>] = [
            .ring: \.ring, .top: \.top, .topRight: \.topRight, .right: \.right,
            .bottomRight: \.bottomRight, .bottom: \.bottom, .bottomLeft: \.bottomLeft,
            .left: \.left, .topLeft: \.topLeft,
        ]
    private static let groups = RadialSettings.groups.map { group in
        RadialEditor.Group(
            title: group.title,
            choices: group.actions.map { action in
                RadialEditor.Choice(
                    id: action.rawValue, title: action.title, detail: action.detail,
                    glyph: action.glyph, cycles: action.isCycle)
            })
    }

    private let logger = Log.logger("Settings")
    private let modules: ModuleManager?
    private let editors = NSHashTable<RadialEditor>.weakObjects()

    var sections: [SettingsSection] {
        let settings = RadialSettings.load(from: modules)
        let ringEditor = RadialEditor(groups: Self.groups)
        ringEditor.actions = Self.actions(settings)
        ringEditor.onPick = { [weak self] slot, id in self?.assign(id, to: slot) }
        editors.add(ringEditor)
        return [
            SettingsSection(
                nil,
                [
                    .init("Radial menu", toggle(\.isEnabled)),
                    .init("Hold to open", trigger(settings)),
                ]),
            SettingsSection(content: ringEditor),
            SettingsSection(nil, Self.toggles.map { .init($0.title, toggle($0.option)) }),
            SettingsSection(content: restoreButton()),
        ]
    }

    init(modules: ModuleManager?) {
        self.modules = modules
    }

    private static func actions(_ settings: RadialSettings) -> [RadialEditor.Slot: String] {
        slots.mapValues { settings[keyPath: $0].rawValue }
    }

    private func toggle(_ option: WritableKeyPath<RadialSettings, Bool>) -> SettingsSwitch {
        let toggle = SettingsSwitch(
            read: { [modules] in RadialSettings.load(from: modules)[keyPath: option] },
            write: { [weak self] isOn in try self?.update { $0[keyPath: option] = isOn } })
        toggle.isEnabled = modules != nil
        return toggle
    }

    private func trigger(_ settings: RadialSettings) -> NSView {
        let button = TriggerButton()
        button.modifiers = settings.trigger
        button.onChange = { [weak self, weak button] trigger in
            guard let self else { return }
            save { $0.trigger = trigger }
            button?.modifiers = RadialSettings.load(from: modules).trigger
        }
        let label = NSTextField(labelWithString: "Ring opens")
        label.textColor = .secondaryLabelColor
        let origin = NSSegmentedControl(
            labels: Self.origins.map(\.title), trackingMode: .selectOne, target: self,
            action: #selector(pickOrigin))
        origin.selectedSegment = Self.origins.firstIndex { $0.origin == settings.opensAt } ?? 0
        origin.isEnabled = modules != nil
        origin.setAccessibilityLabel("Ring opens")
        let controls = NSStackView()
        controls.setViews([button], in: .leading)
        controls.setViews([label, origin], in: .trailing)
        controls.setHuggingPriority(.defaultLow - 1, for: .horizontal)
        return controls
    }

    private func restoreButton() -> NSView {
        let button = NSButton(
            title: "Restore default actions", target: self, action: #selector(restoreDefaults))
        button.isEnabled = modules != nil
        let row = NSStackView()
        row.setViews([button], in: .trailing)
        return row
    }

    @objc
    private func pickOrigin(_ control: NSSegmentedControl) {
        let origin = Self.origins[control.selectedSegment].origin
        save { $0.opensAt = origin }
        let saved = RadialSettings.load(from: modules).opensAt
        control.selectedSegment = Self.origins.firstIndex { $0.origin == saved } ?? 0
    }

    @objc
    private func restoreDefaults() {
        let defaults = RadialSettings()
        save { settings in
            for path in Self.slots.values {
                settings[keyPath: path] = defaults[keyPath: path]
            }
        }
        showActions()
    }

    private func assign(_ id: String, to slot: RadialEditor.Slot) {
        guard let action = RadialSettings.Action(rawValue: id), let path = Self.slots[slot] else {
            return
        }
        save { $0[keyPath: path] = action }
        showActions()
    }

    private func showActions() {
        let actions = Self.actions(RadialSettings.load(from: modules))
        for editor in editors.allObjects {
            editor.actions = actions
        }
    }

    private func save(_ change: (inout RadialSettings) -> Void) {
        do {
            try update(change)
        } catch {
            logger.error("Radial menu settings failed to save: \(error, privacy: .public)")
            NSApp.presentError(error)
        }
    }

    private func update(_ change: (inout RadialSettings) -> Void) throws {
        let old = RadialSettings.load(from: modules)
        var new = old
        change(&new)
        try modules?.setValue(new, for: RadialSettings.key)
        if new.isEnabled != old.isEnabled || new.trigger != old.trigger {
            try modules?.restart(WindowsModule.id)
        }
    }
}
