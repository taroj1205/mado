import AppCore
import AppKit
import InputKit
import SearchKit

@MainActor
final class AppInputSourcesSettings: NSObject {
    private static let iconSize: CGFloat = 26
    private static let popUpWidth: CGFloat = 190

    private let modules: ModuleManager?
    var onChange: (() -> Void)?

    var section: SettingsSection {
        let rows = AppInputSources.load(from: modules).apps.keys
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

    private func row(for id: String) -> SettingsSection.Row? {
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else {
            return nil
        }
        let name = AppIndex.name(of: app)
        let popUp = SettingsPopUp { [weak self] in self?.choices(for: id) ?? [] }
        popUp.isEnabled = modules != nil
        popUp.widthAnchor.constraint(equalToConstant: Self.popUpWidth).isActive = true
        let icon = NSImageView(image: NSWorkspace.shared.icon(forFile: app.path))
        icon.widthAnchor.constraint(equalToConstant: Self.iconSize).isActive = true
        icon.heightAnchor.constraint(equalToConstant: Self.iconSize).isActive = true
        return SettingsSection.Row(name, popUp, icon: icon) {
            "Switches when the app becomes active"
        }
    }

    private func choices(for id: String) -> [SettingsPopUp.Section] {
        let current = AppInputSources.load(from: modules).apps[id]
        let choice = { [weak self] (title: String, value: AppInputSources.Choice) in
            SettingsPopUp.Choice(title: title, isSelected: value == current) {
                self?.update { $0.apps[id] = value }
            }
        }
        var sources = InputSource.selectable.map { choice($0.name, .source(id: $0.id)) }
        if case .source(let stored) = current, !sources.contains(where: \.isSelected) {
            let name = InputSource.installed(id: stored)?.name ?? stored
            var missing = choice(name, .source(id: stored))
            missing.isEnabled = false
            sources.append(missing)
        }
        let remove = SettingsPopUp.Choice(title: "Remove App", isSelected: false) { [weak self] in
            self?.update { $0.apps[id] = nil }
        }
        return [
            .init(title: nil, choices: [choice("Last used", .lastUsed)]),
            .init(title: nil, choices: sources),
            .init(title: nil, choices: [remove]),
        ]
    }

    @objc
    private func addApp(_ sender: NSButton) {
        AppPicker.pick(from: sender) { [weak self] id in
            let source = InputSource.current.map { AppInputSources.Choice.source(id: $0.id) }
            self?.update { $0.apps[id] = $0.apps[id] ?? source ?? .lastUsed }
        }
    }

    private func update(_ change: (inout AppInputSources) -> Void) {
        var settings = AppInputSources.load(from: modules)
        change(&settings)
        settings.save(to: modules)
        onChange?()
    }
}
