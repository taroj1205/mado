import AppCore
import AppKit
import SearchKit

@MainActor
final class FolderListSettings: NSObject {
    private let modules: ModuleManager?
    private let apply: ([URL]) -> Void
    var onChange: (() -> Void)?

    var section: SettingsSection {
        let rows = FileSettings.load(from: modules).paths
            .map(row)
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
        let addButton = SettingsListRow.addButton(
            "Add Folder", enabled: modules != nil, target: self, action: #selector(addFolder))
        return SettingsSection(
            "Folders to search — their files show up as you type", headerAccessory: addButton,
            rows)
    }

    init(modules: ModuleManager?, apply: @escaping ([URL]) -> Void) {
        self.modules = modules
        self.apply = apply
    }

    private func row(for path: String) -> SettingsSection.Row {
        let entry = SettingsListRow.Entry(
            name: FileManager.default.displayName(atPath: path), key: path,
            icon: NSWorkspace.shared.icon(forFile: path),
            detail: FileIndex.abbreviated(URL(filePath: path)))
        var row = SettingsListRow.make(
            entry, enabled: modules != nil, removing: self, action: #selector(removeFolder))
        row.isSearchable = false
        return row
    }

    private func update(_ change: (inout FileSettings) -> Void) {
        var settings = FileSettings.load(from: modules)
        change(&settings)
        settings.save(to: modules)
        apply(settings.folders)
        onChange?()
    }

    @objc
    private func addFolder(_ sender: NSButton) {
        guard let window = unsafe sender.window else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL.homeDirectory
        panel.prompt = "Add"
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK else { return }
            self?.update { settings in panel.urls.forEach { settings.add($0.path) } }
        }
    }

    @objc
    private func removeFolder(_ sender: NSButton) {
        guard let path = sender.identifier?.rawValue else { return }
        update { $0.remove(path) }
    }
}

extension FileSettings: StoredValue {}
