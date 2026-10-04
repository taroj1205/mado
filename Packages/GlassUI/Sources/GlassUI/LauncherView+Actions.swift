public import AppKit

public struct ActionChoice {
    public let title: String
    public let icon: NSImage?
    public let run: @MainActor () -> Void

    public init(_ title: String, icon: NSImage?, run: @escaping @MainActor () -> Void) {
        self.title = title
        self.icon = icon
        self.run = run
    }
}

extension LauncherView {
    public struct Action {
        public static let primaryKeys = [returnKey]
        public static let secondaryKeys = ["⌘", returnKey]
        public static let alternateKeys = ["⌥", returnKey]
        private static let returnKey = "↵"
        private static let modifiers: [(NSEvent.ModifierFlags, String)] = [
            (.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘"),
        ]

        public let title: String
        public let keys: [String]
        public let isDestructive: Bool
        public let choices: (@MainActor () -> [ActionChoice])?
        public var group = 0

        public init(
            _ title: String, keys: [String] = [], isDestructive: Bool = false,
            choices: (@MainActor () -> [ActionChoice])? = nil
        ) {
            self.title = title
            self.keys = keys
            self.isDestructive = isDestructive
            self.choices = choices
        }

        static func keys(_ keys: [String], match event: NSEvent) -> Bool {
            let held = Set(modifiers.filter { event.modifierFlags.contains($0.0) }.map(\.1))
            guard let key = keys.last, !held.isEmpty, Set(keys.dropLast()) == held else {
                return false
            }
            return event.charactersIgnoringModifiers?.uppercased() == key
        }

        func matches(_ event: NSEvent) -> Bool {
            Self.keys(keys, match: event)
        }
    }

    public func handle(_ event: NSEvent) -> Bool {
        if event.type == .leftMouseDown {
            closeCustomiser(unlessAt: event.locationInWindow)
        }
        if editingWidgets {
            return event.type == .leftMouseDown
                && results.convert(results.bounds, to: nil).contains(event.locationInWindow)
        }
        switch event.type {
        case .leftMouseDown
        where field.convert(field.bounds, to: nil).contains(event.locationInWindow):
            endBrowsing()
            return false

        case .leftMouseDown:
            let point = event.locationInWindow
            let onToggle = actionsToggle.convert(actionsToggle.bounds, to: nil).contains(point)
            if !onToggle, actionPanel?.contains(point) != true {
                closeActions()
            }
            return false

        default:
            return false
        }
    }

    func waitsForResults(then retry: @escaping (LauncherView) -> Void) -> Bool {
        guard shownQuery != (field.stringValue, scoped) else { return false }
        afterResults = { [weak self] in
            if let self { retry(self) }
        }
        return true
    }

    func run(_ action: Int) {
        if waitsForResults(then: { $0.run(action) }) { return }
        guard let item = results.selectedItem, action != 0 || !item.action.isEmpty else { return }
        onRun?(item, action)
    }

    func run(keyed keys: [String]) {
        if waitsForResults(then: { $0.run(keyed: keys) }) { return }
        guard let item = results.selectedItem,
            let index = actions?(item).firstIndex(where: { $0.keys == keys })
        else { return }
        onRun?(item, index)
    }

    func runActionShortcut(_ event: NSEvent) -> Bool {
        guard (field.currentEditor() as? NSTextView)?.hasMarkedText() == false else {
            return false
        }
        let item = results.selectedItem
        let index = item.flatMap { actions?($0).firstIndex { $0.matches(event) } }
        guard index != nil || actionKeys.contains(where: { Action.keys($0, match: event) })
        else { return false }
        if waitsForResults(then: { _ = $0.runActionShortcut(event) }) { return true }
        guard let item, let index else { return false }
        onRun?(item, index)
        return true
    }

    func runShortcut(_ key: String) -> Bool {
        let items = results.rows.lazy.compactMap { row in
            if case .item(let item) = row { item } else { nil }
        }
        guard let item = items.first(where: { $0.shortcut == ["⌘", key] }) else { return false }
        if waitsForResults(then: { _ = $0.runShortcut(key) }) { return true }
        onRun?(item, 0)
        return true
    }

    func showActions() {
        if let index = selectedWidget {
            let widget = widgetGrid.shown[index]
            let choices = [Action(widget.action, keys: Action.primaryKeys), Action(Self.editTitle)]
            present(choices, for: widget.name) { [weak self] choice in
                if choice == 0 {
                    self?.onWidget?(widget)
                } else {
                    self?.editWidgets()
                }
            }
            return
        }
        if waitsForResults(then: { $0.showActions() }) { return }
        guard let item = results.selectedItem else { return }
        selectPill(nil)
        present(actions?(item) ?? [], for: item.title) { [weak self] index in
            self?.onRun?(item, index)
        }
    }

    private func present(_ choices: [Action], for title: String, run: @escaping (Int) -> Void) {
        closePreview()
        let menu = actionPanel ?? ActionPanel()
        menu.onRun = { [weak self] index in
            self?.closeActions()
            run(index)
        }
        menu.onClose = { [weak self] in self?.actionsClosed() }
        actionPanel = menu
        actionsToggle.fillColor = ResultRowView.fill
        menu.show(choices, for: title, above: actionCapsule, gap: Self.capsuleInset)
    }

    func toggleActions() {
        if choosingAction {
            closeActions()
        } else {
            showActions()
        }
    }

    func closeActions() {
        actionPanel?.close()
    }

    private func actionsClosed() {
        actionsToggle.fillColor = .clear
        unsafe window?.makeFirstResponder(field)
        field.currentEditor()?.selectedRange = NSRange(
            location: field.stringValue.utf16.count, length: 0)
    }
}
