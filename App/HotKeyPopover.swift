import AppCore
import AppKit
import GlassUI
import SearchKit

@MainActor
final class HotKeyPopover: NSObject, NSPopoverDelegate {
    private let items: ItemEditor
    private let popover = NSPopover()
    private let prompt = HotKeyPrompt()
    private weak var anchor: NSView?

    init(items: ItemEditor) {
        self.items = items
        super.init()
        let content = NSViewController()
        content.view = prompt
        popover.contentViewController = content
        popover.behavior = .transient
        popover.delegate = self
        prompt.onRecording = { [weak items] in items?.suspendHotKeys($0) }
        prompt.onCancel = { [weak popover] in popover?.performClose(nil) }
    }

    func popoverWillClose(_: Notification) {
        unsafe prompt.window?.makeFirstResponder(nil)
    }

    func popoverDidClose(_: Notification) {
        (anchor as? HotKeyButton)?.showsRecording = false
    }

    func button(for id: String, named name: String) -> HotKeyButton {
        let button = HotKeyButton()
        button.shortcut = items.settings[id].hotkey
        button.setAccessibilityLabel("\(name) hotkey")
        button.onPress = { [weak self, weak button] in
            guard let button else { return }
            self?.record(id, named: name, from: button)
        }
        return button
    }

    func record(_ id: String, named name: String, from anchor: NSView) {
        record(
            named: name, clearable: items.settings[id].hotkey != nil, from: anchor,
            conflict: { [weak items] in items?.conflict(for: $0, besides: id) },
            assign: { [weak items] in items?.assign($0, to: id) })
    }

    func record(
        named name: String, clearable: Bool, from anchor: NSView,
        conflict: @escaping (Shortcut) -> String?, assign: @escaping (Shortcut?) -> String?
    ) {
        prompt.conflict = conflict
        prompt.onSave = { [weak self] in self?.save($0, with: assign) }
        prompt.onClear = { [weak self] in _ = self?.save(nil, with: assign) }
        prompt.show(for: name, clearable: clearable)
        self.anchor = anchor
        (anchor as? HotKeyButton)?.showsRecording = true
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
        unsafe prompt.window?.makeFirstResponder(prompt)
    }

    private func save(_ hotkey: Shortcut?, with assign: (Shortcut?) -> String?) -> String? {
        let problem = assign(hotkey)
        if problem == nil {
            popover.close()
        }
        return problem
    }
}
