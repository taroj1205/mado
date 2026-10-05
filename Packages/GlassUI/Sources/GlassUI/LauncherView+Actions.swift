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
        public var detail: String?
        public var opens = false

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
            return handleWhileEditing(event)
        }
        switch event.type {
        case .leftMouseDown
        where field.convert(field.bounds, to: nil).contains(event.locationInWindow):
            endBrowsing()
            return false

        case .leftMouseDown:
            let point = event.locationInWindow
            let onToggle = actionsToggle.convert(actionsToggle.bounds, to: nil).contains(point)
            let inPicker = spotPicker?.contains(point) == true
            let inMenu = widgetMenu?.contains(point) == true
            if !onToggle, !inPicker, !inMenu, actionPanel?.contains(point) != true {
                closeActions()
            }
            return false

        case .rightMouseDown where widgetMenu?.contains(event.locationInWindow) != true:
            closeWidgetMenu()
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
        guard let item = selectedItem, action != 0 || !item.action.isEmpty else { return }
        onRun?(item, action)
    }

    func run(keyed keys: [String]) {
        if waitsForResults(then: { $0.run(keyed: keys) }) { return }
        guard let item = selectedItem,
            let index = actions?(item).firstIndex(where: { $0.keys == keys })
        else { return }
        onRun?(item, index)
    }

    func holdsForResults(_ event: NSEvent) -> Bool {
        guard (field.currentEditor() as? NSTextView)?.hasMarkedText() == false,
            (shortcutKeys + [Self.previewKeys]).contains(where: { Action.keys($0, match: event) })
        else { return false }
        return waitsForResults { view in
            if !view.performKeyEquivalent(with: event) {
                view.passKeyOn(event)
            }
        }
    }

    func runActionShortcut(_ event: NSEvent) -> Bool {
        guard (field.currentEditor() as? NSTextView)?.hasMarkedText() == false,
            let item = selectedItem,
            let index = actions?(item).firstIndex(where: { $0.matches(event) })
        else { return false }
        onRun?(item, index)
        return true
    }

    func runShortcut(_ key: String) -> Bool {
        let items = results.rows.lazy.compactMap { row in
            if case .item(let item) = row { item } else { nil }
        }
        let keys = ["⌘", key.uppercased()]
        guard let item = items.first(where: { $0.shortcut == keys }) else { return false }
        onRun?(item, 0)
        return true
    }

    func showActions() {
        if let index = selectedWidget {
            showActions(for: widgetGrid.shown[index])
            return
        }
        if waitsForResults(then: { $0.showActions() }) { return }
        guard let item = selectedItem else { return }
        selectPill(nil)
        present(actions?(item) ?? [], for: item.title) { [weak self] index in
            self?.onRun?(item, index)
        }
    }

    func present(_ choices: [Action], for title: String, run: @escaping (Int) -> Void) {
        closePreview()
        closeWidgetMenu()
        let menu = actionPanel ?? ActionPanel()
        menu.onRun = { [weak self] index in
            self?.closeActions()
            run(index)
        }
        menu.onClose = { [weak self] in self?.actionsClosed() }
        menu.onOpen = nil
        menu.onCommand = nil
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
        closeWidgetMenu()
    }

    private func actionsClosed() {
        closeSpotPicker()
        actionsToggle.fillColor = .clear
        unsafe window?.makeFirstResponder(field)
        field.currentEditor()?.selectedRange = NSRange(
            location: field.stringValue.utf16.count, length: 0)
    }
}
