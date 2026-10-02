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
        public static let primaryKeys = ["↵"]
        public static let secondaryKeys = ["⌘", "↵"]
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

        func matches(_ event: NSEvent) -> Bool {
            let held = Set(Self.modifiers.filter { event.modifierFlags.contains($0.0) }.map(\.1))
            guard let key = keys.last, !held.isEmpty, Set(keys.dropLast()) == held else {
                return false
            }
            return event.charactersIgnoringModifiers?.uppercased() == key
        }
    }

    public func handle(_ event: NSEvent) -> Bool {
        if event.type == .leftMouseDown {
            closeCustomiser(unlessAt: event.locationInWindow)
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

    func runActionShortcut(_ event: NSEvent) -> Bool {
        guard (field.currentEditor() as? NSTextView)?.hasMarkedText() == false,
            let item = results.selectedItem,
            let index = actions?(item).firstIndex(where: { $0.matches(event) })
        else { return false }
        onRun?(item, index)
        return true
    }

    func runShortcut(_ key: String) -> Bool {
        let items = results.rows.lazy.compactMap { row in
            if case .item(let item) = row { item } else { nil }
        }
        guard let item = items.first(where: { $0.shortcut == ["⌘", key] }) else { return false }
        onRun?(item, 0)
        return true
    }

    func showActions() {
        guard let item = results.selectedItem else { return }
        selectPill(nil)
        closePreview()
        let menu = actionPanel ?? ActionPanel()
        menu.onRun = { [weak self] index in
            self?.closeActions()
            self?.onRun?(item, index)
        }
        menu.onClose = { [weak self] in self?.actionsClosed() }
        actionPanel = menu
        actionsToggle.fillColor = ResultRowView.fill
        menu.show(
            actions?(item) ?? [], for: item.title, above: actionCapsule,
            gap: Self.capsuleInset)
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
