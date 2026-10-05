import AppKit

extension LauncherView {
    public struct Merge: Equatable, Sendable {
        public var title: String
        public var texts: [String]
        public var joins: Bool
        public var note: String
        public var action: String
        public var item: String?

        public init(
            title: String, texts: [String], joins: Bool, note: String, action: String,
            item: String? = nil
        ) {
            self.title = title
            self.texts = texts
            self.joins = joins
            self.note = note
            self.action = action
            self.item = item
        }
    }

    private static let editKeycap = "⌘↵"
    private static let returnKeycap = "↵"

    public var mergeDraft: (merge: Merge, text: String)? {
        mergePane.merge.map { ($0, mergePane.text) }
    }

    public var onSaveSnippet: ((String) -> Void)? {
        get { mergePane.onSnippet }
        set { mergePane.onSnippet = newValue }
    }

    var editsMerge: Bool {
        mergePane.merge != nil || (onEdit != nil && selectedItem?.isCheckable == true)
    }

    public func showMerge(_ merge: Merge?, focusing: Bool = false) {
        mergePane.show(merge, focusing: focusing)
        refreshDetailVisibility()
        showAction(of: selectedItem)
    }

    func placeMerge() {
        mergePane.onEscape = { [weak self] in self?.leaveMergeEditor() }
        mergePane.onFocus = { [weak self] focused in
            let keycap = focused ? Self.editKeycap : Self.returnKeycap
            (self?.actionKeycap as? Keycap)?.name.stringValue = keycap
        }
        mergePane.editor.onShortcut = { [weak self] in self?.mergeShortcut($0) ?? false }
        results.onChecksChanged = { [weak self] in self?.showContext() }
    }

    func refreshDetailVisibility() {
        let previews = if case .preview = shownDetail { true } else { false }
        detail.isHidden = !previews || mergePane.merge != nil
    }

    func extendCommand(_ selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveUpAndModifySelection): results.extendChecks(by: -1)
        case #selector(NSResponder.moveDownAndModifySelection): results.extendChecks(by: 1)
        default: false
        }
    }

    func scopeShortcut(_ key: String) -> Bool {
        if key == "e", editsMerge {
            beginMergeEdit()
            return true
        }
        return openFilter(key)
    }

    private func beginMergeEdit() {
        if mergePane.merge != nil {
            mergePane.focus()
        } else if let item = selectedItem {
            onEdit?(item)
        }
    }

    func endMergeEdit(for item: ResultList.Item?) {
        if let edited = mergePane.merge?.item, edited != item?.id {
            showMerge(nil)
        }
    }

    func mergeShortcut(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(Self.modifierKeys) == .command else { return false }
        switch event.charactersIgnoringModifiers {
        case let key where Self.returnKeys.contains(key):
            if mergePane.merge?.action.isEmpty == false {
                run(0)
            } else {
                run(keyed: Action.secondaryKeys)
            }

        case "k": showActions()
        default: return false
        }
        return true
    }

    private func leaveMergeEditor() {
        unsafe window?.makeFirstResponder(field)
        field.currentEditor()?.selectedRange = NSRange(
            location: field.stringValue.utf16.count, length: 0)
        if mergePane.merge?.item == nil {
            mergePane.rebuild()
        } else {
            showMerge(nil)
        }
    }
}
