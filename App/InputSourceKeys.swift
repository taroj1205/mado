import AppCore
import AppKit
import GlassUI
import InputKit

@MainActor
final class InputSourceKeys: NSObject {
    private struct Target {
        let target: InputTarget
        let label: String
        let chip: String
        let glyph: String
        let detail: String
    }

    private static let fixed = [
        Target(
            target: .english, label: "英数 (ABC)", chip: "英数", glyph: "A",
            detail: "The English source you used last"),
        Target(
            target: .japanese, label: "かな (Japanese)", chip: "かな", glyph: "あ",
            detail: "Your Japanese IME, keeping the one already selected"),
        Target(
            target: .next, label: "Next input source", chip: "Next", glyph: "⇥",
            detail: "Cycles through every source turned on in macOS"),
    ]
    private static let caption =
        "macOS shows its あ / A bubble at the caret.\n"
        + "Mado doesn’t add a HUD of its own."
    private static let tileSize: CGFloat = 26
    private static let tileRadius: CGFloat = 7
    private static let tileFontSize: CGFloat = 13
    private static let fieldWidth: CGFloat = 250
    private static let captionSize: CGFloat = 12
    private static let heroPadding: CGFloat = 16
    private static let heroGap: CGFloat = 14
    private static let heroRadius: CGFloat = 10

    private let modules: ModuleManager?
    private let recorder: HotKeyPopover
    private weak var addButton: NSButton?
    var onChange: (() -> Void)?

    var sections: [SettingsSection] {
        let settings = InputSourceSettings.load(from: modules)
        let sources = settings.keys.compactMap { key -> Target? in
            guard case .source(let id) = key.target else { return nil }
            let name = InputSource.named(id) ?? id
            return Target(
                target: key.target, label: name, chip: name, glyph: String(name.prefix(1)),
                detail: "Selects this source")
        }
        let targets = Self.fixed + sources
        let add = NSButton(
            title: "Add Input Source",
            image: NSImage(systemSymbolName: "plus", accessibilityDescription: nil) ?? NSImage(),
            target: self, action: #selector(showSources))
        add.imagePosition = .imageLeading
        add.isEnabled = modules != nil
        return [
            SettingsSection(content: hero(targets, settings)),
            SettingsSection(
                "Switch with a key", headerAccessory: add,
                targets.map { row(for: $0, hotKey: settings.hotKey(for: $0.target)) }),
        ]
    }

    init(modules: ModuleManager?, recorder: HotKeyPopover) {
        self.modules = modules
        self.recorder = recorder
    }

    private static func tile(_ glyph: String) -> NSView {
        let label = NSTextField(labelWithString: glyph)
        label.font = .systemFont(ofSize: tileFontSize, weight: .bold)
        label.alignment = .center
        let tile = NSBox()
        tile.boxType = .custom
        tile.borderWidth = 0
        tile.cornerRadius = tileRadius
        tile.fillColor = .quaternaryLabelColor
        tile.contentViewMargins = .zero
        label.translatesAutoresizingMaskIntoConstraints = false
        tile.addSubview(label)
        NSLayoutConstraint.activate([
            tile.widthAnchor.constraint(equalToConstant: tileSize),
            tile.heightAnchor.constraint(equalToConstant: tileSize),
            label.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
        ])
        return tile
    }

    private func hero(_ targets: [Target], _ settings: InputSourceSettings) -> NSView {
        var chips: [HotKey.ModifierKey: String] = [:]
        for target in targets {
            if case .modifierTap(let key) = settings.hotKey(for: target.target) {
                chips[key] = target.chip
            }
        }
        let keyboard = TapKeyboard()
        keyboard.show(chips)
        let field = NSTextField()
        field.placeholderString = "Try it here"
        field.widthAnchor.constraint(equalToConstant: Self.fieldWidth).isActive = true
        let note = NSTextField(wrappingLabelWithString: Self.caption)
        note.font = .systemFont(ofSize: Self.captionSize)
        note.textColor = .secondaryLabelColor
        note.alignment = .right
        let tryIt = NSStackView(views: [field, NSView(), note])
        let stack = NSStackView(views: [keyboard, tryIt])
        stack.orientation = .vertical
        stack.spacing = Self.heroGap
        stack.edgeInsets = NSEdgeInsets(
            top: Self.heroPadding, left: Self.heroPadding, bottom: Self.heroPadding,
            right: Self.heroPadding)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = Self.heroRadius
        box.fillColor = .quaternarySystemFill
        box.borderColor = .separatorColor
        box.contentViewMargins = .zero
        box.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: box.topAnchor),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            tryIt.widthAnchor.constraint(
                equalTo: stack.widthAnchor, constant: -(Self.heroPadding + Self.heroPadding)),
        ])
        return box
    }

    private func row(for target: Target, hotKey: HotKey?) -> SettingsSection.Row {
        let button = HotKeyButton()
        button.hotKey = hotKey
        button.onPress = { [weak self, weak button] in
            guard let button else { return }
            self?.record(target.label, for: target.target, clearable: hotKey != nil, from: button)
        }
        return SettingsSection.Row(target.label, button, icon: Self.tile(target.glyph)) {
            target.detail
        }
    }

    @objc
    private func showSources(_ sender: NSButton) {
        let bound = InputSourceSettings.load(from: modules).keys.map(\.target)
        let menu = NSMenu()
        for source in InputSource.enabled where !bound.contains(.source(id: source.id)) {
            let item = NSMenuItem(
                title: source.name, action: #selector(addSource), keyEquivalent: "")
            item.target = self
            item.representedObject = source.id
            menu.addItem(item)
        }
        if menu.items.isEmpty {
            let none = NSMenuItem(title: "Every source has a key", action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
        }
        addButton = sender
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.maxY), in: sender)
    }

    @objc
    private func addSource(_ item: NSMenuItem) {
        guard let id = item.representedObject as? String, let addButton else { return }
        record(item.title, for: .source(id: id), clearable: false, from: addButton)
    }

    private func record(
        _ name: String, for target: InputTarget, clearable: Bool, from anchor: NSView
    ) {
        guard modules != nil else { return }
        recorder.recordKey(named: name, clearable: clearable, from: anchor) { [weak self] key in
            self?.bind(key, to: target)
        }
    }

    private func bind(_ hotKey: HotKey?, to target: InputTarget) {
        var settings = InputSourceSettings.load(from: modules)
        settings.bind(hotKey, to: target)
        settings.save(to: modules)
        do {
            try modules?.restart(KeyboardModule.id)
        } catch {
            NSApp.presentError(error)
        }
        onChange?()
    }
}
