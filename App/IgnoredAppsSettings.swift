import AppCore
import AppKit
import ClipboardKit
import SearchKit
import UniformTypeIdentifiers

@MainActor
final class IgnoredAppsSettings: NSObject {
    private static let removeSize: CGFloat = 20

    private let modules: ModuleManager?
    var onChange: (() -> Void)?

    var section: SettingsSection {
        let rows = ClipboardSettings.load(from: modules).ignoredApps
            .compactMap(row)
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
        let add = NSButton(
            title: "Add App",
            image: NSImage(systemSymbolName: "plus", accessibilityDescription: nil) ?? NSImage(),
            target: self, action: #selector(addApp))
        add.imagePosition = .imageLeading
        add.isEnabled = modules != nil
        return SettingsSection(
            "Ignored apps — nothing copied in these is saved", headerAccessory: add, rows)
    }

    init(modules: ModuleManager?) {
        self.modules = modules
    }

    private func row(for id: String) -> SettingsSection.Row? {
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else {
            return nil
        }
        let name = AppIndex.name(of: app)
        let remove = NSButton(
            image: NSImage(systemSymbolName: "minus", accessibilityDescription: nil) ?? NSImage(),
            target: self, action: #selector(removeApp))
        remove.isBordered = false
        remove.contentTintColor = .secondaryLabelColor
        remove.symbolConfiguration = .init(pointSize: Self.removeSize, weight: .medium)
        remove.identifier = NSUserInterfaceItemIdentifier(id)
        remove.setAccessibilityLabel("Remove \(name)")
        remove.isEnabled = modules != nil
        let control = NSStackView(views: [remove])
        control.setHuggingPriority(.defaultHigh, for: .horizontal)
        let kind = ClipboardSettings.defaultIgnoredApps.first { $0.key == id }?.value
        return SettingsSection.Row(
            name, control, icon: NSWorkspace.shared.icon(forFile: app.path),
            detail: kind.map { kind in { kind } })
    }

    @objc
    private func addApp(_ sender: NSButton) {
        guard let window = unsafe sender.window else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(filePath: "/Applications")
        panel.prompt = "Add"
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let app = panel.url else { return }
            guard let id = Bundle(url: app)?.bundleIdentifier else {
                NSApp.presentError(CocoaError(.fileReadCorruptFile, userInfo: [NSURLErrorKey: app]))
                return
            }
            self?.update { $0.ignore(id) }
        }
    }

    @objc
    private func removeApp(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }
        update { $0.stopIgnoring(id) }
    }

    private func update(_ change: (inout ClipboardSettings) -> Void) {
        var settings = ClipboardSettings.load(from: modules)
        change(&settings)
        settings.save(to: modules)
        onChange?()
    }
}
