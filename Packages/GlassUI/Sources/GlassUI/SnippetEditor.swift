public import AppKit

public final class SnippetEditor: NSView, NSTextFieldDelegate, NSTextViewDelegate {
    public struct Values: Equatable, Sendable {
        public var name: String
        public var keyword: String
        public var text: String

        public init(name: String = "", keyword: String = "", text: String = "") {
            self.name = name
            self.keyword = keyword
            self.text = text
        }
    }

    public struct Entry: Equatable, Sendable {
        public let id: String
        public let values: Values

        public init(id: String, values: Values) {
            self.id = id
            self.values = values
        }
    }

    static let placeholders = ["{date}", "{time}", "{clipboard}", "{cursor}"]
    static let fillIn = "{fill-in}"
    private static let deleteKeys = ["⌃", "X"]

    public var onSave: ((_ id: String?, Values) -> String?)?
    public var onPaste: ((Values) -> Void)?
    public var onDelete: ((String) -> Void)?
    public var onExpandChange: ((Bool) -> Void)?
    public var onClose: (() -> Void)?
    public var fillInToken = ""
    public var tokens: (String) -> [NSRange] = { _ in [] }

    let search = NSTextField()
    let newSnippet = ChipButton(
        font: .systemFont(ofSize: SnippetEditor.newSize, weight: .medium),
        height: SnippetEditor.newHeight, symbol: "plus")
    let list = SnippetList()
    let empty = NSTextField(labelWithString: "")
    let nameField = NSTextField()
    let keywordField = NSTextField()
    let problemLabel = SheetForm.hint()
    let textView = NSTextView()
    let chips = (placeholders + [fillIn]).map { _ in
        ChipButton(font: SnippetEditor.chipFont, height: ChipButton.height, symbol: nil)
    }
    let expandSwitch = NSSwitch()
    let expandDetail = SheetForm.hint()
    let contextPill = StatusPill()
    let paste = CapsuleButton("Paste", keys: LauncherView.Action.secondaryKeys)
    let save = CapsuleButton("Save", keys: LauncherView.Action.primaryKeys)
    let actionsToggle = LauncherView.makeActionsToggle()
    private(set) lazy var buttons = SnippetEditor.capsule([paste, save, actionsToggle])
    private(set) var editing: String?
    private var entries: [Entry] = []
    private(set) var actionPanel: ActionPanel?

    var values: Values {
        Values(
            name: nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            keyword: keywordField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            text: textView.string)
    }

    private var actions: [LauncherView.Action] {
        let delete = LauncherView.Action(
            "Delete Snippet", keys: Self.deleteKeys, isDestructive: true)
        return [
            LauncherView.Action("Paste", keys: LauncherView.Action.secondaryKeys),
            LauncherView.Action("Save", keys: LauncherView.Action.primaryKeys),
        ] + (editing == nil ? [] : [delete])
    }

    override public init(frame: NSRect) {
        super.init(frame: frame)
        for field in [search, nameField, keywordField] {
            field.delegate = self
        }
        textView.delegate = self
        newSnippet.onPress = { [weak self] in self?.startNew() }
        for (chip, token) in zip(chips, Self.placeholders + [Self.fillIn]) {
            chip.title = token
            chip.setAccessibilityLabel("Insert \(token)")
            chip.onPress = { [weak self] in self?.insert(token) }
        }
        expandSwitch.target = self
        expandSwitch.action = #selector(expandChanged)
        list.onSelect = { [weak self] in self?.load($0) }
        paste.onPress = { [weak self] in self?.pasteValues() }
        save.onPress = { [weak self] in self?.saveValues() }
        actionsToggle.onPress = { [weak self] in self?.toggleActions() }
        contextPill.show("Snippets", symbol: "text.alignleft")
        layoutEditor()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    public func show(_ entries: [Entry], selecting id: String?) {
        self.entries = entries
        filter(keeping: id)
    }

    public func showExpansion(_ isOn: Bool, offIn apps: [String]) {
        expandSwitch.state = isOn ? .on : .off
        expandDetail.stringValue = apps.isEmpty ? "" : "Off in: " + apps.joined(separator: ", ")
        expandDetail.isHidden = apps.isEmpty
    }

    public func begin() {
        closeActions()
        search.stringValue = ""
        filter(keeping: editing ?? entries.first?.id)
        unsafe window?.makeFirstResponder(search)
    }

    override public func performKeyEquivalent(with event: NSEvent) -> Bool {
        if let actionPanel, actionPanel.isVisible {
            return actionPanel.performShortcut(event) || super.performKeyEquivalent(with: event)
        }
        if let index = actions.firstIndex(where: { $0.matches(event) }) {
            run(index)
            return true
        }
        guard event.modifierFlags.intersection(LauncherView.modifierKeys) == .command else {
            return super.performKeyEquivalent(with: event)
        }
        switch event.charactersIgnoringModifiers {
        case let key where LauncherView.returnKeys.contains(key): pasteValues()
        case "k": toggleActions()
        default: return super.performKeyEquivalent(with: event)
        }
        return true
    }

    public func controlTextDidChange(_ notification: Notification) {
        if notification.object as? NSTextField === search {
            filter(keeping: list.selectedID)
        }
    }

    public func control(
        _ control: NSControl, textView: NSTextView, doCommandBy selector: Selector
    ) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline) where textView.hasMarkedText(): return false
        case #selector(NSResponder.moveUp) where control === search: list.move(by: -1)
        case #selector(NSResponder.moveDown) where control === search: list.move(by: 1)
        case #selector(NSResponder.insertNewline): saveValues()
        case #selector(NSResponder.cancelOperation): onClose?()
        default: return false
        }
        return true
    }

    public func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertTab): unsafe window?.selectNextKeyView(textView)
        case #selector(NSResponder.insertBacktab): unsafe window?.selectPreviousKeyView(textView)
        case #selector(NSResponder.cancelOperation): onClose?()
        default: return false
        }
        return true
    }

    public func textDidChange(_: Notification) {
        highlightTokens()
    }

    private func filter(keeping id: String?) {
        let query = search.stringValue.trimmingCharacters(in: .whitespaces)
        let shown = entries.filter { entry in
            query.isEmpty
                || [entry.values.name, entry.values.keyword, entry.values.text].contains { field in
                    field.localizedStandardContains(query)
                }
        }
        list.entries = shown
        empty.stringValue = entries.isEmpty ? "No snippets yet" : "No matching snippets"
        empty.isHidden = !shown.isEmpty
        let kept = shown.contains { $0.id == id } ? id : shown.first?.id
        list.select(kept)
        load(kept)
    }

    private func load(_ id: String?) {
        let entry = entries.first { $0.id == id }
        editing = entry?.id
        nameField.stringValue = entry?.values.name ?? ""
        keywordField.stringValue = entry?.values.keyword ?? ""
        textView.string = entry?.values.text ?? ""
        textView.undoManager?.removeAllActions()
        show(problem: nil)
        highlightTokens()
    }

    private func startNew() {
        closeActions()
        list.select(nil)
        load(nil)
        unsafe window?.makeFirstResponder(nameField)
    }

    private func insert(_ token: String) {
        unsafe window?.makeFirstResponder(textView)
        let inserted = token == Self.fillIn ? fillInToken : token
        let start = textView.selectedRange().location
        textView.insertText(inserted, replacementRange: textView.selectedRange())
        guard token == Self.fillIn, let quoted = inserted.firstMatch(of: /"(?<name>[^"]*)"/)
        else { return }
        let name = quoted.output.name
        let range = NSRange(name.startIndex..<name.endIndex, in: inserted)
        textView.setSelectedRange(NSRange(location: start + range.location, length: range.length))
    }

    private func saveValues() {
        let entered = values
        let required: [(value: String, view: NSView)] = [
            (entered.name, nameField), (entered.keyword, keywordField), (entered.text, textView),
        ]
        if let missing = required.first(where: \.value.isEmpty)?.view {
            NSSound.beep()
            unsafe window?.makeFirstResponder(missing)
            return
        }
        show(problem: onSave?(editing, entered))
    }

    private func pasteValues() {
        guard !values.text.isEmpty else {
            NSSound.beep()
            return
        }
        onPaste?(values)
    }

    private func run(_ index: Int) {
        closeActions()
        switch index {
        case 0: pasteValues()
        case 1: saveValues()

        default:
            if let editing { onDelete?(editing) }
        }
    }

    private func toggleActions() {
        if actionPanel?.isVisible == true {
            closeActions()
            return
        }
        let panel = actionPanel ?? ActionPanel()
        let focus = unsafe window?.firstResponder
        panel.onRun = { [weak self] index in self?.run(index) }
        panel.onClose = { [weak self] in
            unsafe self?.window?.makeFirstResponder(focus)
        }
        actionPanel = panel
        let title = values.name.isEmpty ? "New Snippet" : values.name
        panel.show(actions, for: title, above: buttons, gap: Self.capsuleInset)
    }

    private func closeActions() {
        actionPanel?.close()
    }

    func show(problem: String?) {
        problemLabel.stringValue = problem ?? ""
        problemLabel.isHidden = problem == nil
    }

    @objc
    private func expandChanged() {
        onExpandChange?(expandSwitch.state == .on)
    }
}
