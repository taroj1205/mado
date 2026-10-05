import AppCore
import AppKit
import ClipboardKit
import SearchKit

@MainActor
final class AppListSettings: NSObject {
    private static let iconSize: CGFloat = 24
    private static let removeSize: CGFloat = 20

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
        let addButton = NSButton(
            title: "Add App",
            image: NSImage(systemSymbolName: "plus", accessibilityDescription: nil) ?? NSImage(),
            target: self, action: #selector(addApp))
        addButton.imagePosition = .imageLeading
        addButton.isEnabled = modules != nil
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
        let name = AppIndex.name(of: app)
        let removeButton = NSButton(
            image: NSImage(systemSymbolName: "minus", accessibilityDescription: nil) ?? NSImage(),
            target: self, action: #selector(removeApp))
        removeButton.isBordered = false
        removeButton.contentTintColor = .secondaryLabelColor
        removeButton.symbolConfiguration = .init(pointSize: Self.removeSize, weight: .medium)
        removeButton.identifier = NSUserInterfaceItemIdentifier(id)
        removeButton.setAccessibilityLabel("Remove \(name)")
        removeButton.isEnabled = modules != nil
        let control = NSStackView(views: [removeButton])
        control.setHuggingPriority(.defaultHigh, for: .horizontal)
        let icon = NSImageView(image: NSWorkspace.shared.icon(forFile: app.path))
        icon.widthAnchor.constraint(equalToConstant: Self.iconSize).isActive = true
        icon.heightAnchor.constraint(equalToConstant: Self.iconSize).isActive = true
        let kind = detail(id)
        var row = SettingsSection.Row(
            name, control, icon: icon, detail: kind.map { kind in { kind } })
        row.key = id
        return row
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
