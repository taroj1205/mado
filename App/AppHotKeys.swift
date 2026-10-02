import AppCore
import AppKit
import GlassUI
import SearchKit
import UniformTypeIdentifiers
import WindowKit

@MainActor
final class AppHotKeys: NSObject, NSPopoverDelegate {
    private static let mode = "Toggle"
    private static let summary = ": launch if closed → bring to front → hide if already in front."
    static let toggleHint = mode + summary

    private static let modeWidth: CGFloat = 118
    private static let controlGap: CGFloat = 10
    private static let footerSize: CGFloat = 12

    private static var footer: NSAttributedString {
        let text = NSMutableAttributedString(
            string: mode,
            attributes: [
                .font: NSFont.systemFont(ofSize: footerSize, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
            ])
        text.append(
            NSAttributedString(
                string: summary,
                attributes: [
                    .font: NSFont.systemFont(ofSize: footerSize),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ]))
        return text
    }

    private let items: ItemEditor
    private let popover = NSPopover()
    private let prompt = HotKeyPrompt()
    private weak var anchor: NSView?

    var section: SettingsSection {
        let rows = items.settings.hotkeys
            .compactMap { id, hotkey in AppToggle.app(for: id).map { row(for: $0, hotkey: hotkey) }
            }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
        let add = NSButton(
            title: "Add App",
            image: NSImage(systemSymbolName: "plus", accessibilityDescription: nil) ?? NSImage(),
            target: self, action: #selector(addApp))
        add.imagePosition = .imageLeading
        return SettingsSection("App hotkeys", rows, footer: Self.footer, accessory: add)
    }

    init(items: ItemEditor) {
        self.items = items
        super.init()
        let content = NSViewController()
        content.view = prompt
        popover.contentViewController = content
        popover.behavior = .transient
        popover.delegate = self
        prompt.onRecording = { [weak items] in items?.suspendHotKeys($0) }
        prompt.onCancel = { [weak popover] in popover?.performClose(nil) }
    }

    private static func name(of app: URL) -> String {
        FileManager.default.displayName(atPath: app.path).replacing(/\.app$/, with: "")
    }

    func popoverWillClose(_: Notification) {
        unsafe prompt.window?.makeFirstResponder(nil)
    }

    func popoverDidClose(_: Notification) {
        if !popover.isShown {
            (anchor as? HotKeyButton)?.showsRecording = false
        }
    }

    private func row(for app: URL, hotkey: Shortcut) -> SettingsSection.Row {
        let name = Self.name(of: app)
        let modes = NSPopUpButton(frame: .zero, pullsDown: false)
        modes.autoenablesItems = false
        modes.addItems(withTitles: [Self.mode, "Quick Peek"])
        modes.lastItem?.isEnabled = false
        modes.setAccessibilityLabel("\(name) mode")
        modes.widthAnchor.constraint(equalToConstant: Self.modeWidth).isActive = true
        let button = HotKeyButton()
        button.shortcut = hotkey
        button.setAccessibilityLabel("\(name) hotkey")
        button.onPress = { [weak self, weak button] in
            guard let button else { return }
            self?.record(app, from: button)
        }
        let controls = NSStackView(views: [modes, button])
        controls.spacing = Self.controlGap
        controls.setHuggingPriority(.defaultHigh, for: .horizontal)
        return SettingsSection.Row(name, controls, icon: NSWorkspace.shared.icon(forFile: app.path))
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
            self?.record(app, from: sender)
        }
    }

    private func record(_ app: URL, from anchor: NSView) {
        let id = app.path
        prompt.conflict = { [weak items] in items?.conflict(for: $0, besides: id) }
        prompt.onSave = { [weak self] in self?.assign($0, to: id) }
        prompt.onClear = { [weak self] in _ = self?.assign(nil, to: id) }
        prompt.show(for: Self.name(of: app), clearable: items.settings[id].hotkey != nil)
        self.anchor = anchor
        present()
    }

    private func present() {
        guard let anchor else { return }
        (anchor as? HotKeyButton)?.showsRecording = true
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
        unsafe prompt.window?.makeFirstResponder(prompt)
    }

    private func assign(_ hotkey: Shortcut?, to id: String) -> String? {
        popover.close()
        let problem = items.assign(hotkey, to: id)
        if problem != nil {
            present()
        }
        return problem
    }
}
