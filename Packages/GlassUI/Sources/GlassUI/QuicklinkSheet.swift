public import AppCore
public import AppKit

public final class QuicklinkSheet: NSView, NSTextFieldDelegate {
    public struct Values: Equatable, Sendable {
        public var name: String
        public var link: String
        public var app: URL?
        public var icon: Data?
        public var alias: String
        public var hotkey: Shortcut?

        public init(
            name: String = "", link: String = "", app: URL? = nil, icon: Data? = nil,
            alias: String = "", hotkey: Shortcut? = nil
        ) {
            self.name = name
            self.link = link
            self.app = app
            self.icon = icon
            self.alias = alias
            self.hotkey = hotkey
        }
    }

    static let placeholder = "{query}"
    static let symbol = "link"

    public var onSave: ((Values) -> String?)?
    public var onCancel: (() -> Void)?
    public var onRecording: ((Bool) -> Void)? {
        get { hotkey.onRecording }
        set { hotkey.onRecording = newValue }
    }
    public var conflict: (Shortcut) -> String? = { _ in nil }
    public var applications: (String) -> [URL] = { _ in [] }
    public var websiteIcon: (String) async -> Data? = { _ in nil }

    let heading = NSTextField(labelWithString: "")
    let nameField = NSTextField()
    let linkField = NSTextField()
    let linkHint = SheetForm.hint()
    let openWith = NSPopUpButton(frame: .zero, pullsDown: false)
    let tile = NSBox()
    let tileIcon = NSImageView()
    let useWebsiteIcon = NSButton(title: "Use website icon", target: nil, action: nil)
    let aliasField = NSTextField()
    let aliasHint = SheetForm.hint()
    let hotkey = HotKeyButton()
    let problemLabel = SheetForm.hint()
    let contextPill = StatusPill()
    let cancel = CapsuleButton("Cancel", keys: ["esc"])
    let save = CapsuleButton("Save Quicklink", keys: ["↵"])
    private(set) var icon: Data? {
        didSet { showIcon() }
    }
    private(set) var problem: String? {
        didSet { showProblem() }
    }
    private var savedHotkey: Shortcut?

    override public var acceptsFirstResponder: Bool { true }

    var values: Values {
        Values(
            name: nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            link: linkField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            app: openWith.selectedItem?.representedObject as? URL, icon: icon,
            alias: aliasField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            hotkey: hotkey.shortcut)
    }

    override public init(frame: NSRect) {
        super.init(frame: frame)
        for field in [nameField, linkField, aliasField] {
            field.delegate = self
        }
        hotkey.onCapture = { [weak self] in self?.capture($0) }
        hotkey.onClear = { [weak self] in self?.clearHotkey() }
        cancel.onPress = { [weak self] in self?.onCancel?() }
        save.onPress = { [weak self] in self?.saveValues() }
        useWebsiteIcon.target = self
        useWebsiteIcon.action = #selector(fetchWebsiteIcon)
        contextPill.show("Quicklinks", symbol: Self.symbol)
        layoutSheet()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    public func show(_ values: Values, editing: Bool) {
        heading.stringValue = editing ? "Edit Quicklink" : "New Quicklink"
        nameField.stringValue = values.name
        linkField.stringValue = values.link
        aliasField.stringValue = values.alias
        icon = values.icon
        savedHotkey = values.hotkey
        hotkey.shortcut = values.hotkey
        problem = nil
        useWebsiteIcon.isEnabled = true
        listApplications(selecting: values.app, keepingMissing: true)
        showAliasHint()
        unsafe window?.makeFirstResponder(nameField)
    }

    override public func keyDown(with event: NSEvent) {
        interpretKeyEvents([event])
    }

    override public func cancelOperation(_: Any?) {
        onCancel?()
    }

    override public func insertNewline(_: Any?) {
        saveValues()
    }

    override public func insertTab(_: Any?) {
        unsafe window?.selectNextKeyView(self)
    }

    override public func insertBacktab(_: Any?) {
        unsafe window?.selectPreviousKeyView(self)
    }

    public func controlTextDidChange(_ notification: Notification) {
        if notification.object as? NSTextField === linkField {
            listApplications(
                selecting: openWith.selectedItem?.representedObject as? URL, keepingMissing: false)
        }
        showAliasHint()
    }

    public func control(
        _: NSControl, textView: NSTextView, doCommandBy selector: Selector
    ) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline) where textView.hasMarkedText(): return false
        case #selector(NSResponder.insertNewline): saveValues()
        case #selector(NSResponder.cancelOperation): onCancel?()
        default: return false
        }
        return true
    }

    private func capture(_ shortcut: Shortcut) {
        hotkey.shortcut = shortcut
        let keys = HotKeyLabel.keycaps(.shortcut(shortcut)).joined()
        problem =
            shortcut == savedHotkey ? nil : conflict(shortcut).map { "\($0) already uses \(keys)." }
    }

    private func clearHotkey() {
        hotkey.shortcut = nil
        problem = nil
    }

    @objc
    private func fetchWebsiteIcon() {
        let link = values.link
        useWebsiteIcon.isEnabled = false
        Task {
            let data = await websiteIcon(link)
            if let data, values.link == link {
                icon = data
            } else if data == nil {
                NSSound.beep()
            }
            useWebsiteIcon.isEnabled = true
        }
    }

    private func saveValues() {
        let entered = values
        if entered.name.isEmpty || entered.link.isEmpty {
            NSSound.beep()
            unsafe window?.makeFirstResponder(entered.name.isEmpty ? nameField : linkField)
            return
        }
        guard problem == nil else {
            NSSound.beep()
            return
        }
        unsafe window?.makeFirstResponder(self)
        problem = onSave?(entered)
    }

    private func listApplications(selecting wanted: URL?, keepingMissing: Bool) {
        var apps = applications(linkField.stringValue)
        if let wanted, keepingMissing, !apps.contains(wanted) {
            apps.append(wanted)
        }
        openWith.removeAllItems()
        for app in apps {
            let name = FileManager.default.displayName(atPath: app.path)
            openWith.addItem(withTitle: name.replacing(/\.app$/, with: ""))
            openWith.lastItem?.representedObject = app
        }
        if let wanted, let index = apps.firstIndex(of: wanted) {
            openWith.selectItem(at: index)
        }
        openWith.isEnabled = !apps.isEmpty
    }

    private func showAliasHint() {
        let alias = aliasField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !alias.isEmpty else {
            aliasHint.stringValue = "Type the alias in root search to jump straight in."
            return
        }
        let example = linkField.stringValue.contains(Self.placeholder) ? alias + " cats" : alias
        aliasHint.stringValue = "Type “\(example)” in root search to jump straight in."
    }

    private func showIcon() {
        let image = icon.flatMap(NSImage.init(data:))
        tileIcon.image =
            image ?? NSImage(systemSymbolName: Self.symbol, accessibilityDescription: nil)
        tile.fillColor = image == nil ? ResultRowView.fill : .clear
        tile.borderWidth = image == nil ? ItemSheet.tileBorder : 0
    }

    private func showProblem() {
        hotkey.conflict = problem != nil
        problemLabel.stringValue = problem ?? ""
        problemLabel.isHidden = problem == nil
    }
}
