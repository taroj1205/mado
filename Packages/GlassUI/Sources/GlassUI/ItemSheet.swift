public import AppCore
public import AppKit

public final class ItemSheet: NSView, NSTextFieldDelegate {
    public enum Field: Sendable {
        case favourite
        case hotkey
        case aliases

        var symbol: String {
            switch self {
            case .favourite: "star.fill"
            case .hotkey: "keyboard"
            case .aliases: "textformat"
            }
        }

        public func title(favourite: Bool) -> String {
            switch self {
            case .favourite: favourite ? "Remove from Favourites" : "Add to Favourites"
            case .hotkey: "Assign Hotkey…"
            case .aliases: "Add Alias"
            }
        }
    }

    public struct Values: Equatable, Sendable {
        public var aliases: [String]
        public var hotkey: Shortcut?
        public var favourite: Bool
        public var quickPeek: Bool
        public var resetsRanking: Bool

        public init(
            aliases: [String] = [], hotkey: Shortcut? = nil, favourite: Bool = false,
            quickPeek: Bool = false, resetsRanking: Bool = false
        ) {
            self.aliases = aliases
            self.hotkey = hotkey
            self.favourite = favourite
            self.quickPeek = quickPeek
            self.resetsRanking = resetsRanking
        }
    }

    static let aliasHint = "An exact alias match always ranks first"
    static let hotkeyHint =
        "Works from any app. Conflicts with another command are flagged before saving."
    static let neverOpened = "Not opened yet"

    public var onSave: ((Values) -> String?)?
    public var onCancel: (() -> Void)?
    public var onRecording: ((Bool) -> Void)? {
        get { hotkey.onRecording }
        set { hotkey.onRecording = newValue }
    }
    public var conflict: (Shortcut) -> String? = { _ in nil }

    let tile = NSBox()
    let icon = NSImageView()
    let title = NSTextField(labelWithString: "")
    let subtitle = NSTextField(labelWithString: "")
    let chips = NSStackView()
    let aliasField = NSTextField()
    let aliasHintLabel = SheetForm.hint()
    let hotkey = HotKeyButton()
    let clear = NSButton(title: "Clear", target: nil, action: nil)
    let hotkeyHintLabel = SheetForm.hint()
    let mode = AppHotKeyMode.menu()
    let modeHint = SheetForm.hint()
    private(set) lazy var modeRow = SheetForm.row("Mode", [mode, modeHint])
    let favourite = NSSwitch()
    let ranking = NSTextField(labelWithString: "")
    let resetRanking = NSButton(title: "Reset Ranking", target: nil, action: nil)
    let contextPill = StatusPill()
    let cancel = CapsuleButton("Cancel", keys: ["esc"])
    let save = CapsuleButton("Save", keys: ["↵"])
    private(set) var aliases: [String] = [] {
        didSet { showAliases() }
    }
    private(set) var problem: String? {
        didSet { showProblem() }
    }
    private var itemTitle = ""
    private var savedHotkey: Shortcut?
    private var resetsRanking = false

    override public var acceptsFirstResponder: Bool { true }

    var values: Values {
        Values(
            aliases: adding(aliasField.stringValue), hotkey: hotkey.shortcut,
            favourite: favourite.state == .on,
            quickPeek: AppHotKeyMode(selectedIn: mode) == .quickPeek, resetsRanking: resetsRanking)
    }

    override public init(frame: NSRect) {
        super.init(frame: frame)
        aliasField.delegate = self
        hotkey.onCapture = { [weak self] in self?.capture($0) }
        hotkey.onClear = { [weak self] in self?.clearHotkey() }
        cancel.onPress = { [weak self] in self?.onCancel?() }
        save.onPress = { [weak self] in self?.saveValues() }
        for button in [clear, resetRanking] {
            button.target = self
        }
        clear.action = #selector(clearHotkey)
        resetRanking.action = #selector(resetUsage)
        mode.target = self
        mode.action = #selector(showMode)
        layoutSheet()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    public func show(
        _ item: ResultList.Item, values: Values, ranking summary: String?, opening field: Field,
        isApp: Bool = false
    ) {
        itemTitle = item.title
        modeRow.isHidden = !isApp
        mode.setAccessibilityLabel("\(item.title) mode")
        AppHotKeyMode(quickPeek: values.quickPeek).select(in: mode)
        showMode()
        showHeader(item)
        aliasField.stringValue = ""
        aliases = values.aliases
        savedHotkey = values.hotkey
        hotkey.shortcut = values.hotkey
        problem = nil
        let pinned = field == .favourite ? !values.favourite : values.favourite
        favourite.state = pinned ? .on : .off
        favourite.setAccessibilityLabel("Pin \(item.title) to Favourites")
        resetsRanking = false
        ranking.stringValue = summary ?? Self.neverOpened
        resetRanking.isEnabled = summary != nil
        let action = field.title(favourite: values.favourite)
        contextPill.show(
            "⌘K › " + action.trimmingCharacters(in: .init(charactersIn: "…")), symbol: field.symbol)
        let target: NSResponder =
            switch field {
            case .aliases: aliasField
            case .hotkey: hotkey
            case .favourite where favourite.acceptsFirstResponder: favourite
            case .favourite: self
            }
        unsafe window?.makeFirstResponder(target)
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

    public func control(
        _: NSControl, textView: NSTextView, doCommandBy selector: Selector
    ) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline) where textView.hasMarkedText():
            return false

        case #selector(NSResponder.insertNewline) where !aliasField.stringValue.isEmpty:
            aliases = adding(aliasField.stringValue)
            aliasField.stringValue = ""

        case #selector(NSResponder.insertNewline): saveValues()
        case #selector(NSResponder.cancelOperation): onCancel?()
        default: return false
        }
        return true
    }

    @objc
    func removeAlias(_ sender: NSButton) {
        if aliases.indices.contains(sender.tag) {
            aliases.remove(at: sender.tag)
        }
    }

    private func adding(_ text: String) -> [String] {
        let alias = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let known = aliases.contains { $0.caseInsensitiveCompare(alias) == .orderedSame }
        return alias.isEmpty || known ? aliases : aliases + [alias]
    }

    private func capture(_ shortcut: Shortcut) {
        hotkey.shortcut = shortcut
        let keys = HotKeyLabel.keycaps(.shortcut(shortcut)).joined()
        problem =
            shortcut == savedHotkey ? nil : conflict(shortcut).map { "\($0) already uses \(keys)." }
    }

    @objc
    private func clearHotkey() {
        hotkey.shortcut = nil
        problem = nil
    }

    @objc
    private func showMode() {
        let selected = AppHotKeyMode(selectedIn: mode)
        modeHint.stringValue = selected.title + selected.summary
    }

    @objc
    private func resetUsage() {
        resetsRanking = true
        ranking.stringValue = Self.neverOpened
        resetRanking.isEnabled = false
    }

    private func saveValues() {
        guard problem == nil else {
            NSSound.beep()
            return
        }
        unsafe window?.makeFirstResponder(self)
        problem = onSave?(values)
    }

    private func showHeader(_ item: ResultList.Item) {
        icon.image =
            item.icon ?? NSImage(systemSymbolName: item.symbol, accessibilityDescription: nil)
        icon.contentTintColor = item.tint == nil ? .labelColor : .white
        tile.fillColor = item.icon == nil ? item.tint ?? ResultRowView.fill : .clear
        tile.borderWidth = item.icon == nil ? Self.tileBorder : 0
        title.stringValue = item.title
        subtitle.stringValue = [item.kind, item.subtitle].filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func showAliases() {
        chips.setViews(aliases.enumerated().map { chip($0, $1) }, in: .leading)
        aliasHintLabel.stringValue =
            aliases.first.map { alias in
                "\(Self.aliasHint) — “\(alias)” opens \(itemTitle) before anything else "
                    + "starting with \(alias)."
            } ?? "\(Self.aliasHint)."
    }

    private func showProblem() {
        hotkey.conflict = problem != nil
        hotkeyHintLabel.stringValue = problem ?? Self.hotkeyHint
        hotkeyHintLabel.setAccessibilityValue(HotKeyLabel.spoken(text: hotkeyHintLabel.stringValue))
        hotkeyHintLabel.textColor = problem == nil ? .secondaryLabelColor : .systemOrange
        clear.isHidden = hotkey.shortcut == nil
    }
}
