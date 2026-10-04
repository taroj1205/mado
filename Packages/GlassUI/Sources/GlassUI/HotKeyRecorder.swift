public import AppCore
public import AppKit
import Carbon.HIToolbox

public final class HotKeyRecorder: NSView {
    enum State: Equatable {
        case captured(HotKey)
        case conflict(HotKey, String)
        case refused(HotKey, String)
        case waiting
    }

    private static let spacing: CGFloat = 10
    private static let warningGap: CGFloat = 8
    private static let hintSize: CGFloat = 12
    private static let prompt = "Press keys, or tap a modifier alone"
    private static let keyboardSettings = URL(
        string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")

    private static let modifierKeys: [Int: HotKey.ModifierKey] = [
        kVK_Command: .leftCommand, kVK_RightCommand: .rightCommand,
        kVK_Option: .leftOption, kVK_RightOption: .rightOption,
        kVK_Control: .leftControl, kVK_RightControl: .rightControl,
        kVK_Shift: .leftShift, kVK_RightShift: .rightShift,
    ]

    public var onSave: ((HotKey) -> String?)?
    public var onCancel: (() -> Void)?
    public var onClear: (() -> Void)? {
        didSet { render() }
    }
    public var systemConflict: (HotKey) -> String? = { _ in nil }

    private(set) var state = State.waiting {
        didSet { render() }
    }

    private var tapCandidate: HotKey.ModifierKey?
    private var systemHotKeys = SystemHotKeyPause()
    private let field = HotKeyField()
    private let warning = NSStackView()
    private let warningLabel = NSTextField(wrappingLabelWithString: "")
    private let controls = NSStackView()
    private let hint = NSTextField(labelWithString: "")
    private let save = NSButton(title: "Save", target: nil, action: nil)
    private let clear = NSButton(title: "Clear", target: nil, action: nil)
    private let openSettings = NSButton(title: "Open Settings", target: nil, action: nil)
    private let useAnyway = NSButton(title: "Use Anyway", target: nil, action: nil)

    override public var acceptsFirstResponder: Bool { true }

    public init() {
        super.init(frame: .zero)
        for button in [save, useAnyway] {
            button.target = self
            button.action = #selector(saveCaptured)
            button.keyEquivalent = "\r"
        }
        clear.target = self
        clear.action = #selector(clearHotKey)
        openSettings.target = self
        openSettings.action = #selector(openKeyboardSettings)
        field.onPress = { [weak self] in self?.focus() }
        hint.font = .systemFont(ofSize: Self.hintSize)
        hint.textColor = .secondaryLabelColor
        setUpWarning()

        let stack = NSStackView(views: [field, warning, controls])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = Self.spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        for row in [warning, controls] {
            row.setHuggingPriority(.defaultLow - 1, for: .horizontal)
        }
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        render()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    static func modifiers(_ flags: NSEvent.ModifierFlags) -> Shortcut.Modifiers {
        var result: Shortcut.Modifiers = []
        if flags.contains(.command) { result.insert(.command) }
        if flags.contains(.control) { result.insert(.control) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.shift) { result.insert(.shift) }
        return result
    }

    public func reset() {
        tapCandidate = nil
        state = .waiting
    }

    override public func mouseDown(with _: NSEvent) {
        focus()
    }

    override public func becomeFirstResponder() -> Bool {
        systemHotKeys.begin()
        return super.becomeFirstResponder()
    }

    override public func resignFirstResponder() -> Bool {
        systemHotKeys.end()
        return super.resignFirstResponder()
    }

    override public func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            systemHotKeys.end()
        }
    }

    override public func keyDown(with event: NSEvent) {
        tapCandidate = nil
        let modifiers = Self.modifiers(event.modifierFlags)
        if modifiers.isEmpty {
            switch Int(event.keyCode) {
            case kVK_Escape:
                onCancel?()
                return

            case kVK_Delete:
                state = .waiting
                return

            case kVK_Return:
                saveCaptured()
                return

            default:
                break
            }
        }
        capture(.shortcut(Shortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers)))
    }

    override public func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard unsafe window?.firstResponder === self else {
            return super.performKeyEquivalent(with: event)
        }
        keyDown(with: event)
        return true
    }

    override public func flagsChanged(with event: NSEvent) {
        let key = Self.modifierKeys[Int(event.keyCode)]
        let held = Self.modifiers(event.modifierFlags)
        if held.isEmpty, let key, key == tapCandidate {
            capture(.modifierTap(key))
        }
        tapCandidate = key.flatMap { HotKeyLabel.modifier(of: $0) == held ? $0 : nil }
    }

    private func focus() {
        unsafe window?.makeFirstResponder(self)
    }

    private func setUpWarning() {
        warningLabel.font = .systemFont(ofSize: Self.hintSize)
        warningLabel.textColor = .systemOrange
        let icon = NSImageView(
            image: NSImage(
                systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
                ?? NSImage())
        icon.contentTintColor = .systemOrange
        icon.symbolConfiguration = .init(pointSize: Self.hintSize, weight: .medium)
        warning.setViews([icon, warningLabel], in: .leading)
        warning.alignment = .top
        warning.spacing = Self.warningGap
    }

    private func capture(_ hotKey: HotKey) {
        state = systemConflict(hotKey).map { .conflict(hotKey, $0) } ?? .captured(hotKey)
    }

    @objc
    private func saveCaptured() {
        switch state {
        case let .captured(hotKey), let .conflict(hotKey, _):
            if let problem = onSave?(hotKey) {
                state = .refused(hotKey, problem)
            }

        case .refused, .waiting:
            break
        }
    }

    @objc
    private func clearHotKey() {
        onClear?()
    }

    @objc
    private func openKeyboardSettings() {
        if let url = Self.keyboardSettings {
            NSWorkspace.shared.open(url)
        }
    }

    private func render() {
        controls.setViews([], in: .leading)
        controls.setViews([], in: .trailing)
        warning.isHidden = true
        switch state {
        case .waiting:
            field.showPrompt(Self.prompt)
            hint.stringValue = "esc cancels · ⌫ clears"
            controls.setViews([hint], in: .leading)
            controls.setViews(onClear == nil ? [] : [clear], in: .trailing)

        case .captured(let hotKey):
            if case .modifierTap = hotKey {
                field.show(HotKeyLabel.keycaps(hotKey), suffix: "tap", style: .captured)
                hint.stringValue = "Left and right are separate keys"
                controls.setViews([hint], in: .leading)
            } else {
                field.show(HotKeyLabel.keycaps(hotKey), suffix: nil, style: .captured)
            }
            controls.setViews([save], in: .trailing)

        case let .conflict(hotKey, owner):
            let keycaps = HotKeyLabel.keycaps(hotKey)
            field.show(keycaps, suffix: nil, style: .conflict)
            warningLabel.stringValue =
                "\(owner) uses \(keycaps.joined()). Turn it off in System Settings › "
                + "Keyboard Shortcuts, or keep yours anyway."
            warningLabel.setAccessibilityValue(HotKeyLabel.spoken(text: warningLabel.stringValue))
            warning.isHidden = false
            controls.setViews([openSettings, useAnyway], in: .trailing)

        case let .refused(hotKey, problem):
            field.show(HotKeyLabel.keycaps(hotKey), suffix: nil, style: .conflict)
            warningLabel.stringValue = problem
            warningLabel.setAccessibilityValue(problem)
            warning.isHidden = false
            hint.stringValue = "esc cancels · ⌫ clears"
            controls.setViews([hint], in: .leading)
        }
    }
}
