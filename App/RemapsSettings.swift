import AppCore
import AppKit
import GlassUI
import InputKit
import os

@MainActor
final class RemapsSettings: NSObject {
    private static let choices: [(capsLock: RemapSettings.CapsLock, title: String)] = [
        (.capsLock, "Caps Lock"), (.control, "Control"), (.escape, "Escape"), (.hyper, "Hyper"),
    ]
    private static let tapChoices: [(action: RemapSettings.TapAction, title: String)] = [
        (.nothing, "Nothing"), (.escape, "Escape"), (.capsLock, "Caps Lock"),
        (.openMado, "Open Mado"), (.toggleMado, "Toggle Mado"), (.shortcut, "Shortcut…"),
    ]
    private static let controlGap: CGFloat = 10
    private static let tileSize: CGFloat = 26
    private static let tileRadius: CGFloat = 7
    private static let symbolSize: CGFloat = 13
    private static let tileShade: CGFloat = 0.357
    private static let tileBlue: CGFloat = 0.4
    private static let tileFill = NSColor(
        srgbRed: tileShade, green: tileShade, blue: tileBlue, alpha: 1)
    private static let footerSize: CGFloat = 12
    private static let footer = NSAttributedString(
        string: "英数 / かな, fn and the media keys are never remapped. Remaps pause while Secure "
            + "Input is on (password fields) and resume by themselves.",
        attributes: [
            .font: NSFont.systemFont(ofSize: footerSize),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])

    private let logger = Log.logger("Settings")
    private let modules: ModuleManager?
    private let recorder: HotKeyPopover
    private var watcher: KeyboardWatcher?
    var onChange: (() -> Void)?

    var sections: [SettingsSection] {
        let settings = RemapSettings.load(from: modules)
        let glyph = toggle(
            read: { $0.hyperAsGlyph },
            write: { settings, isOn in settings.hyperAsGlyph = isOn })
        glyph.isEnabled = modules != nil && settings.capsLock == .hyper
        return [
            SettingsSection(
                "Caps Lock",
                [
                    .init("Caps Lock key becomes", capsLockPicker(settings)),
                    .init("Tap alone", tapControls(settings), example: nil) {
                        Self.tapDetail(settings.capsLock)
                    },
                    .init("Hyper is", ModifierKeycaps(.hyper), example: nil) {
                        "Record Hyper+T, Hyper+N… anywhere a hotkey is recorded — they never "
                            + "clash with app shortcuts."
                    },
                    .init("Show Hyper as ✦", glyph, example: nil) {
                        "Shortcuts show ✦ in place of ⌃⌥⇧⌘. They’re still saved as ⌃⌥⇧⌘."
                    },
                ]),
            SettingsSection(
                "Apply to keyboards", keyboardRows(settings), footer: Self.footer, accessory: nil),
        ]
    }

    init(modules: ModuleManager?, recorder: HotKeyPopover) {
        self.modules = modules
        self.recorder = recorder
        super.init()
        watcher = KeyboardWatcher { [weak self] in self?.onChange?() }
    }

    private static func tapDetail(_ capsLock: RemapSettings.CapsLock) -> String {
        switch capsLock {
        case .control: "Hold for Control. A quick tap on its own does this instead."
        case .hyper: "Hold for Hyper. A quick tap on its own does this instead."
        case .capsLock, .escape: "Works when Caps Lock becomes Control or Hyper."
        }
    }

    private static func detail(_ parts: String?...) -> String {
        parts.compactMap(\.self).joined(separator: " · ")
    }

    private static func tile() -> NSView {
        let symbol = NSImageView(
            image: NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)
                ?? NSImage())
        symbol.symbolConfiguration = .init(pointSize: symbolSize, weight: .medium)
        symbol.contentTintColor = .white
        let tile = NSBox()
        tile.boxType = .custom
        tile.borderWidth = 0
        tile.cornerRadius = tileRadius
        tile.fillColor = tileFill
        tile.contentViewMargins = .zero
        tile.contentView = symbol
        NSLayoutConstraint.activate([
            tile.widthAnchor.constraint(equalToConstant: tileSize),
            tile.heightAnchor.constraint(equalToConstant: tileSize),
        ])
        return tile
    }

    private func capsLockPicker(_ settings: RemapSettings) -> NSSegmentedControl {
        let picker = NSSegmentedControl(
            labels: Self.choices.map(\.title), trackingMode: .selectOne, target: self,
            action: #selector(pickCapsLock))
        picker.selectedSegment = Self.choices.firstIndex { $0.capsLock == settings.capsLock } ?? 0
        picker.isEnabled = modules != nil
        return picker
    }

    private func tapControls(_ settings: RemapSettings) -> NSView {
        let shortcut = HotKeyButton()
        shortcut.shortcut = settings.tapShortcut
        shortcut.isHidden = settings.tapAction != .shortcut
        shortcut.setAccessibilityLabel("Tap alone shortcut")
        shortcut.onPress = { [weak self, weak shortcut] in
            guard let shortcut else { return }
            self?.recordTapShortcut(from: shortcut)
        }
        let controls = NSStackView()
        let popUp = SettingsPopUp { [weak self, weak anchor = controls, modules] in
            let current = RemapSettings.load(from: modules).tapAction
            let entries = Self.tapChoices.map { choice in
                SettingsPopUp.Choice(title: choice.title, isSelected: choice.action == current) {
                    if choice.action != .shortcut {
                        try self?.update { $0.tapAction = choice.action }
                    } else if let anchor {
                        self?.recordTapShortcut(from: anchor)
                    }
                }
            }
            return [SettingsPopUp.Section(title: nil, choices: entries)]
        }
        popUp.setAccessibilityLabel("Tap alone")
        popUp.isEnabled = modules != nil && settings.capsLock.isModifier
        controls.setViews([popUp, shortcut], in: .leading)
        controls.spacing = Self.controlGap
        controls.setHuggingPriority(.defaultHigh, for: .horizontal)
        return controls
    }

    private func recordTapShortcut(from anchor: NSView) {
        recorder.record(
            named: "Caps Lock tap", clearable: false, from: anchor, conflict: { _ in nil },
            assign: { [weak self] shortcut in
                do {
                    try self?.update { settings in
                        settings.tapAction = .shortcut
                        settings.tapShortcut = shortcut
                    }
                    return nil
                } catch {
                    return error.localizedDescription
                }
            })
    }

    private func keyboardRows(_ settings: RemapSettings) -> [SettingsSection.Row] {
        let connected = KeyboardRemapper.connectedKeyboards()
        let away = settings.excludedKeyboards.filter { keyboard in
            !connected.contains { $0.keyboard == keyboard }
        }
        let connectedRows = connected.map { entry in
            row(entry.keyboard, Self.detail(entry.keyboard.layout?.title, entry.connection?.title))
        }
        let awayRows = away.map { keyboard in
            row(keyboard, Self.detail(keyboard.layout?.title, "not connected"))
        }
        return connectedRows + awayRows
    }

    private func row(_ keyboard: Keyboard, _ detail: String) -> SettingsSection.Row {
        let toggle = toggle(
            read: { $0.applies(to: keyboard) },
            write: { settings, isOn in settings.setApplies(isOn, to: keyboard) })
        return SettingsSection.Row(keyboard.name, toggle, icon: Self.tile()) { detail }
    }

    private func toggle(
        read: @escaping (RemapSettings) -> Bool,
        write: @escaping (inout RemapSettings, Bool) -> Void
    ) -> SettingsSwitch {
        let toggle = SettingsSwitch(
            read: { [modules] in read(RemapSettings.load(from: modules)) },
            write: { [weak self] isOn in try self?.update { write(&$0, isOn) } })
        toggle.isEnabled = modules != nil
        return toggle
    }

    @objc
    private func pickCapsLock(_ picker: NSSegmentedControl) {
        let choice = Self.choices[picker.selectedSegment].capsLock
        do {
            try update { $0.capsLock = choice }
        } catch {
            logger.error("Caps Lock remap failed to save: \(error, privacy: .public)")
            NSApp.presentError(error)
        }
        onChange?()
    }

    private func update(_ change: (inout RemapSettings) -> Void) throws {
        let saved = RemapSettings.load(from: modules)
        var settings = saved
        change(&settings)
        try modules?.setValue(settings, for: RemapSettings.key)
        HyperGlyph.isShown = settings.showsHyperGlyph
        let changesRows =
            (settings.tapAction, settings.tapShortcut, settings.hyperAsGlyph)
            != (saved.tapAction, saved.tapShortcut, saved.hyperAsGlyph)
        defer {
            if changesRows {
                onChange?()
            }
        }
        try modules?.restart(KeyboardModule.id)
    }
}

extension Keyboard.Layout {
    var title: String {
        switch self {
        case .ansi: "US"
        case .iso: "ISO"
        case .jis: "JIS"
        }
    }
}

extension Keyboard.Connection {
    var title: String {
        switch self {
        case .builtIn: "built-in"
        case .bluetooth: "Bluetooth"
        case .usb: "USB"
        }
    }
}
