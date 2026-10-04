import AppCore
import AppKit
import GlassUI
import SearchKit

@MainActor
final class HotKeyPopover: NSObject, NSPopoverDelegate {
    private static let width: CGFloat = 300
    private static let padding: CGFloat = 14
    private static let spacing: CGFloat = 10
    private static let titleSize: CGFloat = 13

    private let items: ItemEditor
    private let popover = NSPopover()
    private let prompt = HotKeyPrompt()
    private let promptContent = NSViewController()
    private let recorder = HotKeyRecorder()
    private let recorderTitle = NSTextField(labelWithString: "")
    private let recorderContent = NSViewController()
    private weak var anchor: NSView?

    init(items: ItemEditor) {
        self.items = items
        super.init()
        promptContent.view = prompt
        recorderContent.view = Self.recorderView(title: recorderTitle, recorder: recorder)
        popover.behavior = .transient
        popover.delegate = self
        prompt.onRecording = { [weak items] in items?.suspendHotKeys($0) }
        prompt.onCancel = { [weak popover] in popover?.performClose(nil) }
        recorder.onCancel = { [weak popover] in popover?.performClose(nil) }
    }

    private static func recorderView(title: NSTextField, recorder: HotKeyRecorder) -> NSView {
        title.font = .systemFont(ofSize: titleSize, weight: .semibold)
        let stack = NSStackView(views: [title, recorder])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = spacing
        stack.edgeInsets = NSEdgeInsets(
            top: padding, left: padding, bottom: padding, right: padding)
        stack.widthAnchor.constraint(equalToConstant: width).isActive = true
        return stack
    }

    func popoverWillClose(_: Notification) {
        unsafe popover.contentViewController?.view.window?.makeFirstResponder(nil)
        items.suspendHotKeys(false)
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
        present(promptContent, focusing: prompt, from: anchor)
    }

    func recordKey(
        named name: String, clearable: Bool, from anchor: NSView,
        refusal: @escaping (HotKey) -> String?, assign: @escaping (HotKey?) -> Void
    ) {
        recorderTitle.stringValue = "Press a key for \(name)"
        recorder.reset()
        recorder.systemConflict = { [weak items] hotKey in
            guard case .shortcut(let shortcut) = hotKey else { return nil }
            return items?.conflict(for: shortcut, besides: "")
        }
        let finish = { [weak popover] (hotKey: HotKey?) in
            assign(hotKey)
            popover?.close()
        }
        recorder.onSave = { hotKey in
            if let problem = refusal(hotKey) {
                return problem
            }
            finish(hotKey)
            return nil
        }
        recorder.onClear = clearable ? { finish(nil) } : nil
        items.suspendHotKeys(true)
        present(recorderContent, focusing: recorder, from: anchor)
    }

    func accepts(_ shortcut: Shortcut) -> Bool {
        items.accepts(shortcut)
    }

    private func present(_ content: NSViewController, focusing view: NSView, from anchor: NSView) {
        popover.contentViewController = content
        self.anchor = anchor
        (anchor as? HotKeyButton)?.showsRecording = true
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
        unsafe view.window?.makeFirstResponder(view)
    }

    private func save(_ hotkey: Shortcut?, with assign: (Shortcut?) -> String?) -> String? {
        let problem = assign(hotkey)
        if problem == nil {
            popover.close()
        }
        return problem
    }
}
