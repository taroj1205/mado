public import AppCore
public import AppKit
import Carbon.HIToolbox

public final class TriggerButton: NSView {
    private static let prompt = "Hold modifier keys"

    public var modifiers: Shortcut.Modifiers = [] {
        didSet { render() }
    }
    public var onChange: ((Shortcut.Modifiers) -> Void)?

    private(set) var isRecording = false
    private(set) var held: Shortcut.Modifiers = []
    private let content = NSStackView()
    private let promptLabel = NSTextField(labelWithString: prompt)
    private let dot = NSBox()

    override public var acceptsFirstResponder: Bool { true }
    override public var canBecomeKeyView: Bool { true }

    public init() {
        super.init(frame: .zero)
        promptLabel.font = .systemFont(ofSize: HotKeyButton.fontSize)
        HotKeyButton.layOut(content, in: self, dot: dot)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        render()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override public func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override public func mouseDown(with _: NSEvent) {
        record()
    }

    override public func accessibilityPerformPress() -> Bool {
        record()
        return true
    }

    override public func becomeFirstResponder() -> Bool {
        isRecording = true
        held = []
        render()
        return super.becomeFirstResponder()
    }

    override public func resignFirstResponder() -> Bool {
        isRecording = false
        held = []
        render()
        return super.resignFirstResponder()
    }

    override public func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard unsafe window?.firstResponder === self else {
            return super.performKeyEquivalent(with: event)
        }
        keyDown(with: event)
        return true
    }

    override public func keyDown(with event: NSEvent) {
        if Int(event.keyCode) == kVK_Escape {
            unsafe window?.makeFirstResponder(nil)
        }
    }

    override public func flagsChanged(with event: NSEvent) {
        var now = HotKeyRecorder.modifiers(event.modifierFlags)
        if event.modifierFlags.contains(.function) {
            now.insert(.function)
        }
        guard now.isEmpty else {
            held.formUnion(now)
            render()
            return
        }
        guard !held.isEmpty else { return }
        modifiers = held
        onChange?(held)
        unsafe window?.makeFirstResponder(nil)
    }

    override public func draw(_: NSRect) {
        HotKeyButton.drawFrame(
            in: bounds, recording: isRecording,
            stroke: isRecording ? .controlAccentColor : HotKeyButton.border)
    }

    private func record() {
        unsafe window?.makeFirstResponder(self)
    }

    private func render() {
        needsDisplay = true
        let padding = isRecording ? HotKeyButton.recordingInset : HotKeyButton.inset
        content.edgeInsets = NSEdgeInsets(top: 0, left: padding, bottom: 0, right: padding)
        content.spacing = isRecording ? HotKeyButton.recordingGap : HotKeyButton.keyGap
        if isRecording, held.isEmpty {
            content.setViews([dot, promptLabel], in: .leading)
            setAccessibilityLabel("Recording trigger. \(Self.prompt), then let go")
            return
        }
        let keys = isRecording ? held : modifiers
        content.setViews(HotKeyButton.keycaps(HotKeyLabel.symbols(keys)), in: .leading)
        setAccessibilityLabel(
            isRecording
                ? "Recording trigger: \(HotKeyLabel.spoken(keys))"
                : "Trigger: hold \(HotKeyLabel.spoken(keys)). Click to record a new trigger")
    }
}
