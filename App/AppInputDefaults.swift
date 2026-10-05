import AppCore
import AppKit
import InputKit
import SearchKit

@MainActor
final class AppInputDefaults: NSObject {
    private static let iconSize: CGFloat = 26
    private static let popUpWidth: CGFloat = 190

    private let modules: ModuleManager?
    var onChange: (() -> Void)?

    var section: SettingsSection {
        let rows = InputSourceSettings.load(from: modules).apps.keys
            .compactMap(row)
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
        let add = NSButton(
            title: "Add App",
            image: NSImage(systemSymbolName: "plus", accessibilityDescription: nil) ?? NSImage(),
            target: self, action: #selector(addApp))
        add.imagePosition = .imageLeading
        add.isEnabled = modules != nil
        return SettingsSection("Default input for each app", headerAccessory: add, rows)
    }

    init(modules: ModuleManager?) {
        self.modules = modules
    }

    private static func choices(
        for current: AppInput?,
        set: @escaping (AppInput?) -> Void
    ) -> [SettingsPopUp.Section] {
        let choice = { (title: String, value: AppInput, enabled: Bool) in
            SettingsPopUp.Choice(title: title, isSelected: value == current, isEnabled: enabled) {
                set(value)
            }
        }
        var sources = InputSource.enabled.map { choice($0.name, .source(id: $0.id), true) }
        if case .source(let id) = current, !sources.contains(where: \.isSelected) {
            sources.append(choice(InputSource.named(id) ?? id, .source(id: id), false))
        }
        return [
            SettingsPopUp.Section(title: nil, choices: sources),
            SettingsPopUp.Section(title: nil, choices: [choice("Last used", .lastUsed, true)]),
            SettingsPopUp.Section(
                title: nil,
                choices: [SettingsPopUp.Choice(title: "Remove", isSelected: false) { set(nil) }]),
        ]
    }

    private func row(for id: String) -> SettingsSection.Row? {
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else {
            return nil
        }
        let popUp = SettingsPopUp { [weak self] in
            Self.choices(for: InputSourceSettings.load(from: self?.modules).apps[id]) { value in
                self?.update { $0.apps[id] = value }
            }
        }
        popUp.isEnabled = modules != nil
        popUp.widthAnchor.constraint(equalToConstant: Self.popUpWidth).isActive = true
        let icon = NSImageView(image: NSWorkspace.shared.icon(forFile: app.path))
        icon.widthAnchor.constraint(equalToConstant: Self.iconSize).isActive = true
        icon.heightAnchor.constraint(equalToConstant: Self.iconSize).isActive = true
        var row = SettingsSection.Row(
            AppIndex.name(of: app), popUp, icon: icon
        ) { "Switches when the app becomes active" }
        row.key = id
        return row
    }

    @objc
    private func addApp(_ sender: NSButton) {
        AppPicker.pickBundleID(from: sender) { [weak self] id in
            self?.update { settings in
                if settings.apps[id] == nil {
                    settings.apps[id] = InputSource.currentID.map { .source(id: $0) } ?? .lastUsed
                }
            }
        }
    }

    private func update(_ change: (inout InputSourceSettings) -> Void) {
        var settings = InputSourceSettings.load(from: modules)
        change(&settings)
        settings.save(to: modules)
        onChange?()
    }
}
