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
    private var watcher: KeyboardWatcher?
    private weak var tapToggle: SettingsSwitch?
    var onChange: (() -> Void)?

    var sections: [SettingsSection] {
        let settings = RemapSettings.load(from: modules)
        let tap = toggle(
            read: { $0.tapSendsEscape },
            write: { settings, isOn in settings.tapSendsEscape = isOn })
        tap.isEnabled = modules != nil && settings.capsLock == .hyper
        tapToggle = tap
        return [
            SettingsSection(
                "Caps Lock",
                [
                    .init("Caps Lock key becomes", capsLockPicker(settings)),
                    .init("Tap alone sends Escape", tap, example: nil) {
                        "Hold for Hyper, tap for Escape."
                    },
                    .init("Hyper is", ModifierKeycaps(HyperKey.modifiers), example: nil) {
                        "Record Hyper+T, Hyper+N… anywhere a hotkey is recorded — they never "
                            + "clash with app shortcuts."
                    },
                ]),
            SettingsSection(
                "Apply to keyboards", keyboardRows(settings), footer: Self.footer, accessory: nil),
        ]
    }

    init(modules: ModuleManager?) {
        self.modules = modules
        super.init()
        watcher = KeyboardWatcher { [weak self] in self?.onChange?() }
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
        let saved = RemapSettings.load(from: modules).capsLock
        picker.selectedSegment = Self.choices.firstIndex { $0.capsLock == saved } ?? 0
        tapToggle?.isEnabled = modules != nil && saved == .hyper
    }

    private func update(_ change: (inout RemapSettings) -> Void) throws {
        var settings = RemapSettings.load(from: modules)
        change(&settings)
        try modules?.setValue(settings, for: RemapSettings.key)
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
