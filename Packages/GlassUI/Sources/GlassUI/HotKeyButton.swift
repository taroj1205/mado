import AppCore
import AppKit
import Carbon.HIToolbox

final class HotKeyButton: NSView {
    private static let height: CGFloat = 26
    private static let inset: CGFloat = 7
    private static let radius: CGFloat = 8
    private static let keyRadius: CGFloat = 5
    private static let keySize: CGFloat = 18
    private static let keyGap: CGFloat = 3
    private static let fontSize: CGFloat = 12.5
    private static let lineWidth: CGFloat = 1
    private static let half: CGFloat = 0.5
    private static let chordModifiers: Shortcut.Modifiers = [.command, .control, .option]
    private static let fillAlpha = (dark: 0.06, light: 0.04)
    private static let borderAlpha = (dark: 0.10, light: 0.12)
    private static let keycapAlpha = (dark: 0.12, light: 0.08)
    private static let fill = adaptive(fillAlpha)
    private static let border = adaptive(borderAlpha)
    private static let keycapFill = adaptive(keycapAlpha)

    var shortcut: Shortcut? {
        didSet { render() }
    }
    var conflict = false {
        didSet { needsDisplay = true }
    }
    var onCapture: ((Shortcut) -> Void)?
    var onClear: (() -> Void)?
    var onRecording: ((Bool) -> Void)?

    private let content = NSStackView()
    private let prompt = NSTextField(labelWithString: "")
    private var systemHotKeys = SystemHotKeyPause()

    var isRecording: Bool { systemHotKeys.isActive }

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    init() {
        super.init(frame: .zero)
        content.spacing = Self.keyGap
        content.setHuggingPriority(.defaultHigh, for: .horizontal)
        content.translatesAutoresizingMaskIntoConstraints = false
        prompt.font = .systemFont(ofSize: Self.fontSize)
        prompt.textColor = .secondaryLabelColor
        addSubview(content)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.inset),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.inset),
            content.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Hotkey")
        render()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func adaptive(_ alpha: (dark: Double, light: Double)) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? .white.withAlphaComponent(alpha.dark) : .black.withAlphaComponent(alpha.light)
        }
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with _: NSEvent) {
        focus()
    }

    override func accessibilityPerformPress() -> Bool {
        focus()
        return true
    }

    override func becomeFirstResponder() -> Bool {
        systemHotKeys.begin()
        onRecording?(true)
        render()
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        stopRecording()
        return super.resignFirstResponder()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            stopRecording()
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard unsafe window?.firstResponder === self else {
            return super.performKeyEquivalent(with: event)
        }
        keyDown(with: event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = HotKeyRecorder.modifiers(event.modifierFlags)
        if !modifiers.isDisjoint(with: Self.chordModifiers) {
            onCapture?(Shortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers))
        } else if modifiers.isEmpty, Int(event.keyCode) == kVK_Delete {
            onClear?()
        } else {
            interpretKeyEvents([event])
        }
    }

    override func draw(_: NSRect) {
        let edge = Self.lineWidth * Self.half
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: edge, dy: edge), xRadius: Self.radius,
            yRadius: Self.radius)
        Self.fill.setFill()
        path.fill()
        let stroke: NSColor =
            if conflict {
                .systemOrange
            } else if isRecording {
                .controlAccentColor
            } else {
                Self.border
            }
        stroke.setStroke()
        path.lineWidth = Self.lineWidth
        path.stroke()
    }

    private func focus() {
        unsafe window?.makeFirstResponder(self)
    }

    private func stopRecording() {
        guard isRecording else { return }
        systemHotKeys.end()
        onRecording?(false)
        render()
    }

    private func render() {
        needsDisplay = true
        guard let shortcut else {
            prompt.stringValue = isRecording ? "Press keys…" : "Record Hotkey"
            content.setViews([prompt], in: .leading)
            setAccessibilityValue(prompt.stringValue)
            return
        }
        let keys = HotKeyLabel.keycaps(.shortcut(shortcut))
        content.setViews(
            keys.map { key in
                let keycap = Keycap(key, radius: Self.keyRadius, size: Self.keySize)
                keycap.fillColor = Self.keycapFill
                keycap.name.textColor = .labelColor
                return keycap
            }, in: .leading)
        setAccessibilityValue(keys.joined(separator: " "))
    }
}
