import AppCore
import AppKit
import GlassUI
import InputKit
import SearchKit
import UniformTypeIdentifiers

@MainActor
final class EnterGuardPage: NSObject {
    private struct Card {
        let keys: [String]
        let title: String
        let detail: String
    }

    private static let cards = [
        Card(
            keys: ["↵"], title: "New line",
            detail: "In a chat composer, Enter never sends a half-written prompt."),
        Card(
            keys: ["⌘", "↵"], title: "Send",
            detail: "Sends the message, the same in every guarded app."),
    ]
    private static let iconSize: CGFloat = 26
    private static let keySize: CGFloat = 20
    private static let keyRadius: CGFloat = 5
    private static let keyGap: CGFloat = 3
    private static let titleGap: CGFloat = 6
    private static let titleSize: CGFloat = 13
    private static let detailSize: CGFloat = 12
    private static let cardGap: CGFloat = 10
    private static let cardRadius: CGFloat = 10
    private static let cardVertical: CGFloat = 12
    private static let cardHorizontal: CGFloat = 14

    private let modules: ModuleManager?
    var onChange: (() -> Void)?

    var sections: [SettingsSection] {
        let settings = EnterGuardSettings.load(from: modules)
        let builtIns = EnterGuardSettings.builtIns.map { app in
            row(app.name, app.bundleIDs, detail: "Built-in")
        }
        let added = settings.addedApps.compactMap { id in
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: id).map { app in
                row(AppIndex.name(of: app), [id], detail: "Added by you")
            }
        }
        let add = NSButton(
            title: "Add App",
            image: NSImage(systemSymbolName: "plus", accessibilityDescription: nil) ?? NSImage(),
            target: self, action: #selector(addApp))
        add.imagePosition = .imageLeading
        add.isEnabled = modules != nil
        let enabled = toggle(read: \.isOn) { settings, isOn in settings.isOn = isOn }
        return [
            SettingsSection(
                nil,
                [
                    .init("Enter Guard", enabled, example: nil) {
                        "The Enter that confirms a Japanese conversion is never touched."
                    }
                ]),
            SettingsSection(content: Self.cardRow()),
            SettingsSection("Guarded apps", headerAccessory: add, builtIns + added),
        ]
    }

    init(modules: ModuleManager?) {
        self.modules = modules
    }

    private static func cardRow() -> NSView {
        let row = NSStackView(views: cards.map(card))
        row.distribution = .fillEqually
        row.alignment = .top
        row.spacing = cardGap
        return row
    }

    private static func card(_ card: Card) -> NSView {
        let keys = NSStackView(
            views: card.keys.map { Keycap($0, radius: keyRadius, size: keySize) })
        keys.spacing = keyGap
        keys.setAccessibilityElement(false)
        keys.setHuggingPriority(.defaultHigh, for: .horizontal)
        let title = NSTextField(labelWithString: card.title)
        title.font = .systemFont(ofSize: titleSize, weight: .semibold)
        let heading = NSStackView(views: [keys, title])
        heading.spacing = titleGap
        let detail = NSTextField(wrappingLabelWithString: card.detail)
        detail.font = .systemFont(ofSize: detailSize)
        detail.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [heading, detail])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = titleGap
        stack.edgeInsets = NSEdgeInsets(
            top: cardVertical, left: cardHorizontal, bottom: cardVertical, right: cardHorizontal)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let box = NSBox()
        box.boxType = .custom
        box.titlePosition = .noTitle
        box.cornerRadius = cardRadius
        box.fillColor = .quaternarySystemFill
        box.borderColor = .separatorColor
        box.contentViewMargins = .zero
        box.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: box.topAnchor),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor),
        ])
        return box
    }

    private static func icon(for apps: [String]) -> NSImageView {
        let path = apps.lazy.compactMap(NSWorkspace.shared.urlForApplication(withBundleIdentifier:))
            .first?.path
        let icon = NSImageView(
            image: path.map(NSWorkspace.shared.icon(forFile:))
                ?? NSWorkspace.shared.icon(for: .applicationBundle))
        icon.widthAnchor.constraint(equalToConstant: iconSize).isActive = true
        icon.heightAnchor.constraint(equalToConstant: iconSize).isActive = true
        return icon
    }

    private func row(_ name: String, _ apps: [String], detail: String) -> SettingsSection.Row {
        let control = toggle(
            read: { settings in apps.allSatisfy(settings.guards) },
            write: { settings, isOn in settings.setGuarding(apps, isOn) })
        return SettingsSection.Row(name, control, icon: Self.icon(for: apps)) { detail }
    }

    private func toggle(
        read: @escaping (EnterGuardSettings) -> Bool,
        write: @escaping (inout EnterGuardSettings, Bool) -> Void
    ) -> SettingsSwitch {
        let control = SettingsSwitch(
            read: { [weak self] in read(EnterGuardSettings.load(from: self?.modules)) },
            write: { [weak self] isOn in try self?.update { write(&$0, isOn) } })
        control.isEnabled = modules != nil
        return control
    }

    @objc
    private func addApp(_ sender: NSButton) {
        AppPicker.pickBundleID(from: sender) { [weak self] id in
            do {
                try self?.update { $0.add(id) }
            } catch {
                NSApp.presentError(error)
            }
            self?.onChange?()
        }
    }

    private func update(_ change: (inout EnterGuardSettings) -> Void) throws {
        var settings = EnterGuardSettings.load(from: modules)
        change(&settings)
        settings.save(to: modules)
        try modules?.restart(KeyboardModule.id)
    }
}
