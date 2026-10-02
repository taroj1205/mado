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

    func showActions() {
        guard let item = results.selectedItem else { return }
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
