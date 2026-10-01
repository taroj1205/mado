public import AppCore
public import AppKit

@MainActor
public final class HotkeyRecorderView: NSView {
    private typealias Style = HotkeyRecorderStyle

    public var onCommit: ((HotkeyCapture) -> Void)?
    public var onCancel: (() -> Void)?
    public var onClear: (() -> Void)?
    public var onOpenSettings: (() -> Void)?

    private var model: HotkeyRecorderModel
    private let content = NSStackView()

    override public var acceptsFirstResponder: Bool { true }

    private var accessibilityDescription: String {
        let prefix = "Hotkey recorder."
        switch model.state {
        case .waiting:
            return "\(prefix) Press keys, or tap a modifier alone."

        case let .captured(capture):
            return "\(prefix) Captured \(capture.keyCaps.joined(separator: " "))."

        case let .conflict(capture, owner):
            return "\(prefix) \(capture.keyCaps.joined(separator: " ")) conflicts with \(owner)."
        }
    }

    public init(findConflict: @escaping (Shortcut) -> String? = { _ in nil }) {
        model = HotkeyRecorderModel(findConflict: findConflict)
        super.init(frame: .zero)
        appearance = NSAppearance(named: .darkAqua)
        wantsLayer = true
        layer?.cornerRadius = Style.cardRadius
        layer?.masksToBounds = true
        layer?.borderWidth = Style.cardBorderWidth
        layer?.borderColor = Style.cardBorder.cgColor

        let glass = NSVisualEffectView()
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.translatesAutoresizingMaskIntoConstraints = false
        addSubview(glass)

        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = Style.spacing
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Style.cardWidth),
            glass.leadingAnchor.constraint(equalTo: leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: trailingAnchor),
            glass.topAnchor.constraint(equalTo: topAnchor),
            glass.bottomAnchor.constraint(equalTo: bottomAnchor),
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Style.inset),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Style.inset),
            content.topAnchor.constraint(equalTo: topAnchor, constant: Style.inset),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Style.inset),
        ])
        render()
    }

    public required init?(coder _: NSCoder) {
        nil
    }

    override public func resignFirstResponder() -> Bool {
        model.releaseAllModifiers()
        return super.resignFirstResponder()
    }

    override public func keyDown(with event: NSEvent) {
        handleKey(event)
    }

    override public func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard unsafe window?.firstResponder === self else {
            return false
        }
        handleKey(event)
        return true
    }

    override public func flagsChanged(with event: NSEvent) {
        guard let key = ModifierKey(keyCode: event.keyCode) else {
            return
        }
        if event.modifierFlags.rawValue & key.deviceMask != 0 {
            model.modifierDown(key)
        } else {
            model.modifierUp(key)
        }
        render()
    }

    private func handleKey(_ event: NSEvent) {
        guard !event.isARepeat else {
            return
        }
        let flags = event.modifierFlags
        var modifiers: Shortcut.Modifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        let name = HotkeyCapture.keyName(
            keyCode: event.keyCode, characters: event.charactersIgnoringModifiers)
        switch model.keyDown(keyCode: event.keyCode, modifiers: modifiers, keyName: name) {
        case .cancel:
            onCancel?()

        case .clear:
            onClear?()

        case .recorded:
            break
        }
        render()
    }

    private func commit() {
        if let capture = model.capture {
            onCommit?(capture)
        }
    }

    private func render() {
        for view in content.arrangedSubviews {
            content.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        switch model.state {
        case .waiting:
            add(
                HotkeyFieldBox(
                    border: Style.waitingBorder, dashed: true,
                    views: [
                        dot(), note("Press keys, or tap a modifier alone", font: Style.bodyFont),
                    ]
                ))
            add(note("esc cancels · ⌫ clears"))

        case let .captured(capture):
            add(capturedField(capture, border: Style.blue))
            add(capturedFooter(capture))

        case let .conflict(capture, owner):
            add(capturedField(capture, border: Style.orange))
            add(warning(owner: owner, capture: capture))
            add(
                buttonRow([
                    HotkeyPillButton(title: "Open Settings", filled: false) { [weak self] in
                        self?.onOpenSettings?()
                    },
                    HotkeyPillButton(title: "Use Anyway", filled: true) { [weak self] in
                        self?.commit()
                    },
                ]))
        }
        setAccessibilityLabel(accessibilityDescription)
    }

    private func capturedField(_ capture: HotkeyCapture, border: NSColor) -> NSView {
        var views: [NSView] = capture.keyCaps.map(HotkeyKeyCapView.init)
        if case .modifierTap = capture {
            views.append(note("tap"))
        }
        return HotkeyFieldBox(border: border, dashed: false, views: views)
    }

    private func capturedFooter(_ capture: HotkeyCapture) -> NSView {
        let save = HotkeyPillButton(title: "Save", filled: true) { [weak self] in
            self?.commit()
        }
        guard case .modifierTap = capture else {
            return buttonRow([save])
        }
        return buttonRow([save], leading: note("Left and right are separate keys"))
    }

    private func warning(owner: String, capture: HotkeyCapture) -> NSView {
        let message = NSTextField(
            wrappingLabelWithString:
                "\(owner) uses \(capture.keyCaps.joined()). "
                + "Turn it off in System Settings › Keyboard Shortcuts, or keep yours anyway.")
        message.font = Style.noteFont
        message.textColor = Style.warningText
        message.preferredMaxLayoutWidth = Style.warningTextWidth
        let icon = NSImageView(
            image: NSImage(
                systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
                ?? NSImage())
        icon.contentTintColor = Style.orange
        icon.setContentHuggingPriority(.required, for: .horizontal)
        let row = NSStackView(views: [icon, message])
        row.alignment = .top
        row.spacing = Style.warningSpacing
        return row
    }

    private func buttonRow(_ buttons: [NSView], leading: NSView? = nil) -> NSView {
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: (leading.map { [$0] } ?? []) + [spacer] + buttons)
        row.spacing = Style.buttonSpacing
        row.alignment = .centerY
        return row
    }

    private func add(_ view: NSView) {
        content.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
    }

    private func dot() -> NSView {
        let dot = NSView()
        dot.wantsLayer = true
        dot.layer?.cornerRadius = Style.dotRadius
        dot.layer?.backgroundColor = Style.red.cgColor
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: Style.dotSize),
            dot.heightAnchor.constraint(equalToConstant: Style.dotSize),
        ])
        return dot
    }

    private func note(_ string: String, font: NSFont = Style.noteFont) -> NSTextField {
        let label = NSTextField(labelWithString: string)
        label.font = font
        label.textColor = Style.secondary
        return label
    }
}
