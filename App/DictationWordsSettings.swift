import AppCore
import AppKit
import SpeechKit

@MainActor
final class DictationWordsSettings: NSObject {
    private static let fieldWidth: CGFloat = 180
    private static let rankLimit = 50

    private let modules: ModuleManager?
    private var addedField: NSTextField?
    var onChange: (() -> Void)?

    var section: SettingsSection {
        let words = DictationSettings.load(from: modules).words.list
        let rows = words.enumerated().map { row(for: $1, rank: $0 + 1, of: words.count) }
        var built = SettingsSection(
            "Custom words — dictation spells these your way, top ones first",
            headerAccessory: addField(), rows,
            footer: SettingsSection.footnote(
                "Names and terms you say. They help Whisper spell those words the way you write "
                    + "them here, but don't guarantee it. Drag a word, or use the arrows, to move "
                    + "it. When the list is too long for Whisper, the words at the bottom are "
                    + "left out. Parakeet models ignore it."))
        if modules != nil {
            built.reorder = { [weak self] word, target in
                self?.update { $0.move(word, before: target) }
            }
        }
        return built
    }

    init(modules: ModuleManager?) {
        self.modules = modules
    }

    private func addField() -> NSTextField {
        if let addedField { return addedField }
        let field = NSTextField()
        field.placeholderString = "Add a word"
        field.setAccessibilityLabel("Add a word")
        field.target = self
        field.action = #selector(addWord)
        field.isEnabled = modules != nil
        field.widthAnchor.constraint(equalToConstant: Self.fieldWidth).isActive = true
        addedField = field
        return field
    }

    private func row(for word: String, rank: Int, of count: Int) -> SettingsSection.Row {
        let raise = SettingsListRow.iconButton(
            "chevron.up", label: "Move \(word) up", key: word, target: self,
            action: #selector(moveUp))
        raise.isEnabled = rank > 1
        let lower = SettingsListRow.iconButton(
            "chevron.down", label: "Move \(word) down", key: word, target: self,
            action: #selector(moveDown))
        lower.isEnabled = rank < count
        let symbol = rank <= Self.rankLimit ? "\(rank).circle" : "circle"
        let entry = SettingsListRow.Entry(
            name: word, key: word,
            icon: NSImage(systemSymbolName: symbol, accessibilityDescription: "Number \(rank)")
                ?? NSImage(),
            detail: nil)
        var row = SettingsListRow.make(
            entry, enabled: modules != nil, removing: self, action: #selector(removeWord),
            beforeRemove: [raise, lower])
        row.isSearchable = false
        return row
    }

    private func update(_ change: (inout SpeechWords) -> Void) {
        var settings = DictationSettings.load(from: modules)
        change(&settings.words)
        settings.save(to: modules)
        onChange?()
    }

    @objc
    private func addWord(_ sender: NSTextField) {
        let text = sender.stringValue
        sender.stringValue = ""
        update { $0.add(text) }
        unsafe sender.window?.makeFirstResponder(sender)
    }

    @objc
    private func removeWord(_ sender: NSButton) {
        guard let word = sender.identifier?.rawValue else { return }
        update { $0.remove(word) }
    }

    @objc
    private func moveUp(_ sender: NSButton) {
        guard let word = sender.identifier?.rawValue else { return }
        update { $0.move(word, by: -1) }
    }

    @objc
    private func moveDown(_ sender: NSButton) {
        guard let word = sender.identifier?.rawValue else { return }
        update { $0.move(word, by: 1) }
    }
}
