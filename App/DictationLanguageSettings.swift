import AppCore
import AppKit
import SpeechKit

@MainActor
final class DictationLanguageSettings: NSObject {
    private let modules: ModuleManager?
    var onChange: (() -> Void)?

    var section: SettingsSection {
        let selected = DictationSettings.load(from: modules).languages.codes
        let rows =
            selected
            .map { row(for: $0, isLast: selected.count == 1) }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
        return SettingsSection(
            "Languages — dictation picks one of these each time you talk",
            headerAccessory: addMenu(excluding: selected), rows)
    }

    init(modules: ModuleManager?) {
        self.modules = modules
    }

    private static func name(of code: String, in locale: Locale) -> String {
        locale.localizedString(forLanguageCode: code) ?? code
    }

    private static func ownName(of code: String) -> String {
        name(of: code, in: Locale(identifier: code))
    }

    private static func menuTitle(of code: String) -> String {
        let own = ownName(of: code)
        let local = name(of: code, in: .current)
        return own == local ? local : "\(local) — \(own)"
    }

    private func row(for code: String, isLast: Bool) -> SettingsSection.Row {
        let own = Self.ownName(of: code)
        let local = Self.name(of: code, in: .current)
        let entry = SettingsListRow.Entry(
            name: own, key: code,
            icon: NSImage(systemSymbolName: "globe", accessibilityDescription: nil) ?? NSImage(),
            detail: own == local ? code : local)
        var row = SettingsListRow.make(
            entry, enabled: modules != nil && !isLast, removing: self,
            action: #selector(removeLanguage))
        row.isSearchable = false
        return row
    }

    private func addMenu(excluding selected: [String]) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: true)
        button.addItem(withTitle: "Add Language")
        button.item(at: 0)?.image = NSImage(
            systemSymbolName: "plus", accessibilityDescription: nil)
        let rest = SpeechLanguages.supported.filter { !selected.contains($0) }
            .map { (code: $0, title: Self.menuTitle(of: $0)) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        for language in rest {
            let item = NSMenuItem(
                title: language.title, action: #selector(addLanguage), keyEquivalent: "")
            item.target = self
            item.representedObject = language.code
            button.menu?.addItem(item)
        }
        button.isEnabled = modules != nil && !rest.isEmpty
        return button
    }

    private func update(_ change: (inout SpeechLanguages) -> Void) {
        var settings = DictationSettings.load(from: modules)
        change(&settings.languages)
        settings.save(to: modules)
        onChange?()
    }

    @objc
    private func addLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        update { $0.add(code) }
    }

    @objc
    private func removeLanguage(_ sender: NSButton) {
        guard let code = sender.identifier?.rawValue else { return }
        update { $0.remove(code) }
    }
}
