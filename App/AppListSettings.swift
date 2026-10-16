import AppCore
import AppKit
import ClipboardKit
import SearchKit

@MainActor
final class AppListSettings: NSObject {
    private let title: String
    private let modules: ModuleManager?
    private let apps: () -> [String]
    private let add: (String) -> Void
    private let remove: (String) -> Void
    private let detail: (String) -> String?
    var onChange: (() -> Void)?

    var section: SettingsSection {
        let rows = apps()
            .compactMap(row)
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
        let addButton = SettingsListRow.addButton(
            "Add App", enabled: modules != nil, target: self, action: #selector(addApp))
        return SettingsSection(title, headerAccessory: addButton, rows)
    }

    private init(
        _ title: String, modules: ModuleManager?, apps: @escaping () -> [String],
        add: @escaping (String) -> Void, remove: @escaping (String) -> Void,
        detail: @escaping (String) -> String?
    ) {
        self.title = title
        self.modules = modules
        self.apps = apps
        self.add = add
        self.remove = remove
        self.detail = detail
    }

    static func ignoredApps(modules: ModuleManager?) -> AppListSettings {
        AppListSettings(
            "Ignored apps — nothing copied in these is saved", modules: modules,
            apps: { ClipboardSettings.load(from: modules).ignoredApps },
            add: { app in update(ClipboardSettings.self, in: modules) { $0.ignore(app) } },
            remove: { app in update(ClipboardSettings.self, in: modules) { $0.stopIgnoring(app) } },
            detail: { id in ClipboardSettings.defaultIgnoredApps.first { $0.key == id }?.value })
    }

    static func withoutExpansion(modules: ModuleManager?) -> AppListSettings {
        AppListSettings(
            "No expansion — snippets don’t expand in these apps", modules: modules,
            apps: { SnippetSettings.load(from: modules).appsWithoutExpansion },
            add: { app in update(SnippetSettings.self, in: modules) { $0.stopExpanding(in: app) } },
            remove: { app in update(SnippetSettings.self, in: modules) { $0.expandAgain(in: app) }
            },
            detail: { _ in nil })
    }

    private static func update<Value: StoredValue>(
        _: Value.Type, in modules: ModuleManager?, _ change: (inout Value) -> Void
    ) {
        var settings = Value.load(from: modules)
        change(&settings)
        settings.save(to: modules)
    }

    private func row(for id: String) -> SettingsSection.Row? {
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else {
            return nil
        }
        let entry = SettingsListRow.Entry(
            name: AppIndex.name(of: app), key: id,
            icon: NSWorkspace.shared.icon(forFile: app.path), detail: detail(id))
        return SettingsListRow.make(
            entry, enabled: modules != nil, removing: self, action: #selector(removeApp))
    }

    @objc
    private func addApp(_ sender: NSButton) {
        AppPicker.pickBundleID(from: sender) { [weak self] id in
            self?.add(id)
            self?.onChange?()
        }
    }

    @objc
    private func removeApp(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }
        remove(id)
        onChange?()
    }
}
