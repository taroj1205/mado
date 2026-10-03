import AppKit
import GlassUI
import SearchKit
import UniformTypeIdentifiers
import WindowKit

@MainActor
final class AppHotKeys: NSObject {
    private static let modeWidth: CGFloat = 118
    private static let controlGap: CGFloat = 10
    private static let footerSize: CGFloat = 12
    private static let iconSize: CGFloat = 26

    private static var footer: NSAttributedString {
        let title: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: footerSize, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
        ]
        let summary: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: footerSize),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let text = NSMutableAttributedString()
        for mode in AppHotKeyMode.allCases {
            if text.length > 0 {
                text.append(NSAttributedString(string: " ", attributes: summary))
            }
            text.append(NSAttributedString(string: mode.title, attributes: title))
            text.append(NSAttributedString(string: mode.summary, attributes: summary))
        }
        return text
    }

    private let items: ItemEditor
    private let recorder: HotKeyPopover

    var section: SettingsSection {
        let rows = items.settings.hotkeys.keys
            .compactMap { AppToggle.app(for: $0).map(row) }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
        let add = NSButton(
            title: "Add App",
            image: NSImage(systemSymbolName: "plus", accessibilityDescription: nil) ?? NSImage(),
            target: self, action: #selector(addApp))
        add.imagePosition = .imageLeading
        return SettingsSection("App hotkeys", rows, footer: Self.footer, accessory: add)
    }

    init(items: ItemEditor, recorder: HotKeyPopover) {
        self.items = items
        self.recorder = recorder
        super.init()
    }

    private static func name(of app: URL) -> String {
        FileManager.default.displayName(atPath: app.path).replacing(/\.app$/, with: "")
    }

    private func row(for app: URL) -> SettingsSection.Row {
        let name = Self.name(of: app)
        let modes = AppHotKeyMode.Menu()
        modes.selected = AppHotKeyMode(quickPeek: items.settings[app.path].quickPeek)
        modes.onChange = { [weak items] in items?.setQuickPeek($0 == .quickPeek, for: app.path) }
        modes.setAccessibilityLabel("\(name) mode")
        modes.widthAnchor.constraint(equalToConstant: Self.modeWidth).isActive = true
        let controls = NSStackView(views: [modes, recorder.button(for: app.path, named: name)])
        controls.spacing = Self.controlGap
        controls.setHuggingPriority(.defaultHigh, for: .horizontal)
        let icon = NSImageView(image: NSWorkspace.shared.icon(forFile: app.path))
        icon.widthAnchor.constraint(equalToConstant: Self.iconSize).isActive = true
        icon.heightAnchor.constraint(equalToConstant: Self.iconSize).isActive = true
        return SettingsSection.Row(name, controls, icon: icon)
    }

    @objc
    private func addApp(_ sender: NSButton) {
        guard let window = unsafe sender.window else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(filePath: "/Applications")
        panel.prompt = "Add"
        panel.beginSheetModal(for: window) { [weak self, weak sender] response in
            guard response == .OK, let app = panel.url, let sender else { return }
            self?.recorder.record(app.path, named: Self.name(of: app), from: sender)
        }
    }
}
