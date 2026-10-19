import AppCore
import AppKit
import InputKit
import WindowKit

@MainActor
final class ModifierKeysSettings: NSObject {
    private struct KeyRow {
        let key: ModifierTap.Key
        let name: String
        let kind: String
    }

    private static let keys = [
        KeyRow(key: .leftCommand, name: "Left ⌘", kind: "Command"),
        KeyRow(key: .rightCommand, name: "Right ⌘", kind: "Command"),
        KeyRow(key: .leftOption, name: "Left ⌥", kind: "Option"),
        KeyRow(key: .rightOption, name: "Right ⌥", kind: "Option"),
        KeyRow(key: .leftControl, name: "Left ⌃", kind: "Control"),
        KeyRow(key: .rightControl, name: "Right ⌃", kind: "Control"),
        KeyRow(key: .function, name: "fn", kind: "Globe"),
        KeyRow(key: .leftShift, name: "Left ⇧", kind: "Shift"),
        KeyRow(key: .rightShift, name: "Right ⇧", kind: "Shift"),
    ]
    private static let doubleTap = 2
    private static let tripleTap = 3
    private static let repeats = [
        (count: doubleTap, title: "Double tap"), (count: tripleTap, title: "Triple tap"),
    ]
    private static let note =
        "A tap fires only when the key is pressed and released alone, so normal shortcuts like "
        + "⌘C keep working. Left and right keys are separate."
    private static let chipGap: CGFloat = 8
    private static let chipsPerLine = 2
    private static let cellInset: CGFloat = 3
    private static let warningMark = "⚠︎ "

    let modules: ModuleManager?
    private let remaps: RemapsSettings
    var onChange: (() -> Void)?

    var assignments: TapAssignments {
        TapAssignments(
            inputSources: InputSourceSettings.load(from: modules),
            bindings: ModifierBindings.load(from: modules))
    }

    var sections: [SettingsSection] {
        let current = assignments
        let capsLock = RemapSettings.load(from: modules)
        let rows = Self.keys.map { row($0, current, capsLock: capsLock) } + [remaps.capsLockTapRow]
        var tapAlone = SettingsSection(
            "Tap alone", rows, footer: footer(for: current), accessory: nil)
        let shownClaims = Self.systemClaims(of: current)
        tapAlone.refresh = { [weak self] in
            guard let self, Self.systemClaims(of: assignments) != shownClaims else { return }
            onChange?()
        }
        return [
            SettingsSection(
                content: SettingsPageController.footer(SettingsSection.footnote(Self.note))),
            tapAlone,
        ]
    }

    init(modules: ModuleManager?, remaps: RemapsSettings) {
        self.modules = modules
        self.remaps = remaps
    }

    static func name(of key: ModifierTap.Key) -> String {
        keys.first { $0.key == key }?.name ?? ""
    }

    static func title(of tap: ModifierTap.Tap, besides key: ModifierTap.Key) -> String {
        if let other = tap.keys.subtracting([key]).first {
            return "With \(name(of: other))"
        }
        return repeats.first { $0.count == tap.count }?.title ?? "Tap"
    }

    private static func systemClaims(of assignments: TapAssignments) -> [String?] {
        assignments.entries.map { SystemTapClaims.use(of: $0.tap) }
    }

    static func taps(of key: ModifierTap.Key) -> [ModifierTap.Tap] {
        let others = ModifierTap.Key.allCases.filter { $0 != key }
        return [ModifierTap.Tap(key)] + repeats.map { ModifierTap.Tap(key, count: $0.count) }
            + others.map { ModifierTap.Tap(key, $0) }
    }

    private static func phrase(of tap: ModifierTap.Tap) -> String {
        let names = ModifierTap.Key.allCases.filter(tap.keys.contains).map(name).joined(
            separator: " + ")
        guard let repeated = repeats.first(where: { $0.count == tap.count }) else {
            return "\(names) tap"
        }
        return "\(names) \(repeated.title.lowercased())"
    }

    func title(of action: ModifierAction) -> String {
        switch action {
        case .inputSource(let target):
            return InputSourceKeys.label(of: target)

        case .item(let id):
            if let app = AppToggle.app(for: id) {
                return AppHotKeys.name(of: app)
            }
            return modules?.commands.command(id: id)?.name ?? id
        }
    }

    func bind(_ action: ModifierAction?, to tap: ModifierTap.Tap) {
        var current = assignments
        current.bind(action, to: tap)
        current.inputSources.save(to: modules)
        current.bindings.save(to: modules)
        do {
            try modules?.restart(KeyboardModule.id)
        } catch {
            NSApp.presentError(error)
        }
        Task { @MainActor [onChange] in onChange?() }
    }

    private func row(
        _ entry: KeyRow, _ current: TapAssignments, capsLock: RemapSettings
    ) -> SettingsSection.Row {
        let taps = Self.taps(of: entry.key)
        var chips = taps.compactMap { tap in
            current.action(for: tap).map { chip(for: tap, $0, on: entry, capsLock: capsLock) }
        }
        let free = taps.filter { !capsLock.claims($0) && current.action(for: $0) == nil }
        if !free.isEmpty {
            chips.append(addChip(for: entry, free: free))
        }
        let lines = stride(from: 0, to: chips.count, by: Self.chipsPerLine).map { start in
            let line = NSStackView(
                views: Array(chips[start..<min(start + Self.chipsPerLine, chips.count)]))
            line.spacing = Self.chipGap
            line.setHuggingPriority(.required, for: .horizontal)
            return line
        }
        let cell = NSStackView(views: lines)
        cell.orientation = .vertical
        cell.alignment = .leading
        cell.spacing = Self.chipGap
        cell.edgeInsets = NSEdgeInsets(
            top: Self.cellInset, left: 0, bottom: Self.cellInset, right: 0)
        cell.setHuggingPriority(.defaultHigh, for: .horizontal)
        return .init(entry.name, cell, example: nil) { entry.kind }
    }

    private func chip(
        for tap: ModifierTap.Tap, _ action: ModifierAction, on entry: KeyRow,
        capsLock: RemapSettings
    ) -> TapChip {
        let warning =
            capsLock.claims(tap)
            ? "Caps Lock’s tap uses this key"
            : SystemTapClaims.use(of: tap).map { _ in "macOS also uses \(entry.name)" }
        let gesture =
            tap == ModifierTap.Tap(entry.key) ? nil : Self.title(of: tap, besides: entry.key)
        let subtitle = [gesture?.lowercased(), warning].compactMap(\.self).joined(separator: " · ")
        let title = title(of: action)
        let chip = TapChip(
            title, subtitle: subtitle.isEmpty ? nil : subtitle,
            style: warning == nil ? .filled : .warning)
        chip.isEnabled = modules != nil
        chip.setAccessibilityLabel(
            ([Self.phrase(of: tap), title] + [warning].compactMap(\.self)).joined(separator: ", "))
        chip.onPress = { [weak self, weak chip] in
            guard let chip else { return }
            self?.choose(tap, current: action, from: chip)
        }
        return chip
    }

    private func addChip(for entry: KeyRow, free: [ModifierTap.Tap]) -> TapChip {
        let chip = TapChip("Add", subtitle: nil, style: .add)
        chip.isEnabled = modules != nil
        chip.setAccessibilityLabel("Add a tap for \(entry.name)")
        chip.onPress = { [weak self, weak chip] in
            guard let chip, let menu = self?.gestures(besides: entry.key, free: free, from: chip)
            else { return }
            chip.show(menu)
        }
        return chip
    }

    private func footer(for current: TapAssignments) -> NSAttributedString? {
        let lines = current.entries.compactMap { entry in
            SystemTapClaims.use(of: entry.tap).map { use in
                "\(Self.warningMark)\(Self.phrase(of: entry.tap)) is also used by macOS for \(use)"
                    + " — change it in System Settings › Keyboard, or pick another key."
            }
        }
        guard !lines.isEmpty else { return nil }
        let text = NSMutableAttributedString(
            attributedString: SettingsSection.footnote(lines.joined(separator: "\n")))
        text.addAttribute(
            .foregroundColor, value: NSColor.systemOrange,
            range: NSRange(location: 0, length: text.length))
        return text
    }
}
