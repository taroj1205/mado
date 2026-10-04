public import AppCore
public import AppKit
import Carbon.HIToolbox

public final class HotKeyButton: NSView {
    private static let height: CGFloat = 26
    static let inset: CGFloat = 7
    private static let radius: CGFloat = 8
    private static let keyRadius: CGFloat = 5
    private static let keySize: CGFloat = 18
    static let keyGap: CGFloat = 3
    static let fontSize: CGFloat = 12.5
    private static let lineWidth: CGFloat = 1
    private static let recordingLineWidth: CGFloat = 1.5
    static let recordingInset: CGFloat = 10
    private static let recordingFill: CGFloat = 0.14
    private static let dotSize: CGFloat = 7
    static let recordingGap: CGFloat = 6
    private static let half: CGFloat = 0.5
    static let chordModifiers: Shortcut.Modifiers = [.command, .control, .option]
    private static let fillAlpha = (dark: 0.06, light: 0.04)
    private static let borderAlpha = (dark: 0.10, light: 0.12)
    private static let keycapAlpha = (dark: 0.12, light: 0.08)
    private static let fill = adaptive(fillAlpha)
    static let border = adaptive(borderAlpha)
    private static let keycapFill = adaptive(keycapAlpha)

    public var hotKey: HotKey? {
        didSet { render() }
    }
    public var shortcut: Shortcut? {
        get {
            guard case .shortcut(let shortcut) = hotKey else { return nil }
            return shortcut
        }
        set { hotKey = newValue.map(HotKey.shortcut) }
    }
    public var onPress: (() -> Void)?
    public var showsRecording = false {
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
    private let tapSuffix = NSTextField(labelWithString: "tap")
    private let dot = NSBox()
    private var systemHotKeys = SystemHotKeyPause()

    var isRecording: Bool { systemHotKeys.isActive }

    override public var acceptsFirstResponder: Bool { onPress == nil }
    override public var canBecomeKeyView: Bool { onPress == nil }

    public init() {
        super.init(frame: .zero)
        prompt.font = .systemFont(ofSize: Self.fontSize)
        tapSuffix.font = .systemFont(ofSize: Self.fontSize)
        tapSuffix.textColor = .secondaryLabelColor
        Self.layOut(content, in: self, dot: dot)
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

    static func layOut(_ content: NSStackView, in view: NSView, dot: NSBox) {
        content.setHuggingPriority(.defaultHigh, for: .horizontal)
        content.translatesAutoresizingMaskIntoConstraints = false
        dot.boxType = .custom
        dot.borderWidth = 0
        dot.cornerRadius = dotSize * half
        dot.fillColor = .systemRed
        view.addSubview(content)
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: height),
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            content.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: dotSize),
            dot.heightAnchor.constraint(equalToConstant: dotSize),
        ])
    }

    static func drawFrame(in bounds: NSRect, recording: Bool, stroke: NSColor) {
        let width = recording ? recordingLineWidth : lineWidth
        let edge = width * half
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: edge, dy: edge), xRadius: radius, yRadius: radius)
        let background =
            recording ? NSColor.controlAccentColor.withAlphaComponent(recordingFill) : fill
        background.setFill()
        path.fill()
        stroke.setStroke()
        path.lineWidth = width
        path.stroke()
    }

    static func keycaps(_ keys: [String]) -> [NSView] {
        keys.map { key in
            let keycap = Keycap(key, radius: keyRadius, size: keySize)
            keycap.fillColor = keycapFill
            keycap.name.textColor = .labelColor
            return keycap
        }
    }

    override public func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override public func mouseDown(with _: NSEvent) {
        press()
    }

    override public func accessibilityPerformPress() -> Bool {
        press()
        return true
    }

    override public func becomeFirstResponder() -> Bool {
        systemHotKeys.begin()
        onRecording?(true)
        render()
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
        if !modifiers.isDisjoint(with: Self.chordModifiers) {
            onCapture?(Shortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers))
        } else if modifiers.isEmpty, Int(event.keyCode) == kVK_Delete {
            onClear?()
        } else {
            interpretKeyEvents([event])
        }
    }

    override public func draw(_: NSRect) {
        let stroke: NSColor =
            if conflict {
                .systemOrange
            } else if isRecording || showsRecording {
                .controlAccentColor
            } else {
                Self.border
            }
        Self.drawFrame(in: bounds, recording: showsRecording, stroke: stroke)
    }

    private func press() {
        if let onPress {
            onPress()
        } else {
            unsafe window?.makeFirstResponder(self)
        }
    }

    private func stopRecording() {
        guard isRecording else { return }
        systemHotKeys.end()
        onRecording?(false)
        render()
    }

    private func render() {
        needsDisplay = true
        let padding = showsRecording ? Self.recordingInset : Self.inset
        content.edgeInsets = NSEdgeInsets(top: 0, left: padding, bottom: 0, right: padding)
        content.spacing = showsRecording ? Self.recordingGap : Self.keyGap
        prompt.textColor = showsRecording ? .labelColor : .secondaryLabelColor
        if showsRecording {
            prompt.stringValue = "Recording…"
            content.setViews([dot, prompt], in: .leading)
            setAccessibilityValue(prompt.stringValue)
            return
        }
        guard let hotKey else {
            prompt.stringValue = isRecording ? "Press keys…" : "Record Hotkey"
            content.setViews([prompt], in: .leading)
            setAccessibilityValue(prompt.stringValue)
            return
        }
        var keys = HotKeyLabel.keycaps(hotKey)
        var views = Self.keycaps(keys)
        if case .modifierTap = hotKey {
            keys.append(tapSuffix.stringValue)
            views.append(tapSuffix)
        }
        content.setViews(views, in: .leading)
        setAccessibilityValue(HotKeyLabel.spoken(text: keys.joined(separator: " ")))
    }
}
