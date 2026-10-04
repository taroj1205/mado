public import AppCore
public import AppKit

public final class HotKeyPrompt: NSView {
    private static let width: CGFloat = 300
    private static let padding: CGFloat = 14
    private static let spacing: CGFloat = 10
    private static let titleSize: CGFloat = 13
    private static let warningSize: CGFloat = 12
    private static let fieldHeight: CGFloat = 44
    private static let waiting = "Press keys…"
    private static let keySuffix = "+ key"

    public var onSave: ((Shortcut) -> String?)?
    public var onClear: (() -> Void)?
    public var onCancel: (() -> Void)?
    public var onRecording: ((Bool) -> Void)?
    public var conflict: (Shortcut) -> String? = { _ in nil }

    let title = NSTextField(labelWithString: "")
    let field = HotKeyField(height: HotKeyPrompt.fieldHeight)
    let warning = NSTextField(wrappingLabelWithString: "")
    let clear = NSButton(title: "Clear", target: nil, action: nil)
    let cancel = NSButton(title: "Cancel", target: nil, action: nil)
    private var systemHotKeys = SystemHotKeyPause()

    override public var acceptsFirstResponder: Bool { true }

    public init() {
        super.init(frame: .zero)
        title.font = .systemFont(ofSize: Self.titleSize, weight: .semibold)
        warning.font = .systemFont(ofSize: Self.warningSize)
        warning.textColor = .systemOrange
        clear.target = self
        clear.action = #selector(deleteBackward)
        cancel.target = self
        cancel.action = #selector(cancelOperation)
        field.onPress = { [weak self] in self?.focus() }
        let buttons = NSStackView()
        buttons.setViews([clear], in: .leading)
        buttons.setViews([cancel], in: .trailing)
        let stack = NSStackView(views: [title, field, warning, buttons])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = Self.spacing
        stack.edgeInsets = NSEdgeInsets(
            top: Self.padding, left: Self.padding, bottom: Self.padding, right: Self.padding)
        stack.translatesAutoresizingMaskIntoConstraints = false
        title.setContentHuggingPriority(.defaultLow - 1, for: .horizontal)
        buttons.setHuggingPriority(.defaultLow - 1, for: .horizontal)
        addSubview(stack)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.width),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    public func show(for name: String, clearable: Bool) {
        title.stringValue = "Press a shortcut for \(name)"
        clear.isEnabled = clearable
        warning.isHidden = true
        showHeld([])
    }

    override public func mouseDown(with _: NSEvent) {
        focus()
    }

    override public func becomeFirstResponder() -> Bool {
        systemHotKeys.begin()
        onRecording?(true)
        return super.becomeFirstResponder()
    }

    override public func resignFirstResponder() -> Bool {
        stopRecording()
        return super.resignFirstResponder()
    }

    override public func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            stopRecording()
        }
    }

    override public func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard unsafe window?.firstResponder === self else {
            return super.performKeyEquivalent(with: event)
        }
        keyDown(with: event)
        return true
    }

    override public func keyDown(with event: NSEvent) {
        let modifiers = HotKeyRecorder.modifiers(event.modifierFlags)
        if modifiers.isDisjoint(with: HotKeyButton.chordModifiers) {
            interpretKeyEvents([event])
        } else {
            capture(Shortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers))
        }
    }

    override public func flagsChanged(with event: NSEvent) {
        let held = HotKeyRecorder.modifiers(event.modifierFlags)
        if !held.isEmpty || warning.isHidden {
            warning.isHidden = true
            showHeld(held)
        }
    }

    override public func cancelOperation(_: Any?) {
        onCancel?()
    }

    override public func deleteBackward(_: Any?) {
        if clear.isEnabled {
            onClear?()
        }
    }

    private func focus() {
        unsafe window?.makeFirstResponder(self)
    }

    private func stopRecording() {
        guard systemHotKeys.isActive else { return }
        systemHotKeys.end()
        onRecording?(false)
    }

    private func capture(_ shortcut: Shortcut) {
        let keys = HotKeyLabel.keycaps(.shortcut(shortcut))
        let taken = conflict(shortcut).map { "\($0) already uses \(keys.joined())." }
        guard let problem = taken ?? save(shortcut) else { return }
        field.show(keys, suffix: nil, style: .conflict)
        warning.stringValue = problem
        warning.setAccessibilityValue(HotKeyLabel.spoken(text: problem))
        warning.isHidden = false
    }

    private func save(_ shortcut: Shortcut) -> String? {
        unsafe window?.makeFirstResponder(nil)
        let problem = onSave?(shortcut)
        if problem != nil {
            focus()
        }
        return problem
    }

    private func showHeld(_ modifiers: Shortcut.Modifiers) {
        let symbols = HotKeyLabel.symbols(modifiers)
        if symbols.isEmpty {
            field.showPrompt(Self.waiting)
        } else {
            field.show(symbols, suffix: Self.keySuffix, style: .waiting)
        }
    }
}
