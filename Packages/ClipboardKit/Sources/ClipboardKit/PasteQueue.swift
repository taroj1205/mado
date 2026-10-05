import Carbon.HIToolbox
public import CoreGraphics
import InputKit

public struct PasteQueue: Sendable {
    public enum Key: Equatable, Sendable {
        case paste
        case clear
    }

    private static let shortcutFlags: CGEventFlags = [
        .maskCommand, .maskShift, .maskAlternate, .maskControl,
    ]

    public private(set) var waiting: [Clip]
    public private(set) var pasted: [Clip]

    public var next: Clip? {
        waiting.first
    }

    public init() {
        waiting = []
        pasted = []
    }

    @MainActor
    public static func key(for event: CGEvent) -> Key? {
        guard !Keystrokes.isPosted(event),
            event.getIntegerValueField(.keyboardEventAutorepeat) == 0
        else { return nil }
        let code = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        switch event.flags.intersection(shortcutFlags) {
        case .maskCommand:
            let paste = KeyboardLayout.commandKeyCode(typing: "v") ?? CGKeyCode(kVK_ANSI_V)
            return code == paste ? .paste : nil

        case []:
            return code == CGKeyCode(kVK_Escape) ? .clear : nil

        default:
            return nil
        }
    }

    public mutating func add(_ clip: Clip) {
        waiting.append(clip)
    }

    public mutating func advance() {
        guard !waiting.isEmpty else { return }
        pasted.append(waiting.removeFirst())
    }
}
