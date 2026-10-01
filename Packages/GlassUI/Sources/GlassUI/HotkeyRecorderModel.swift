public import AppCore
import Carbon.HIToolbox

public struct HotkeyRecorderModel {
    public enum State: Equatable, Sendable {
        case captured(HotkeyCapture)
        case conflict(HotkeyCapture, owner: String)
        case waiting
    }

    public enum Effect: Equatable, Sendable {
        case cancel
        case clear
        case recorded
    }

    private static let escapeKeyCode = UInt16(kVK_Escape)
    private static let deleteKeyCode = UInt16(kVK_Delete)

    public private(set) var state = State.waiting

    private let findConflict: (Shortcut) -> String?
    private var heldModifiers: Set<ModifierKey> = []
    private var tappedModifier: ModifierKey?

    public var capture: HotkeyCapture? {
        switch state {
        case .waiting:
            nil

        case let .captured(capture), let .conflict(capture, _):
            capture
        }
    }

    public init(findConflict: @escaping (Shortcut) -> String? = { _ in nil }) {
        self.findConflict = findConflict
    }

    @discardableResult
    public mutating func keyDown(
        keyCode: UInt16, modifiers: Shortcut.Modifiers, keyName: String
    ) -> Effect {
        tappedModifier = nil
        if modifiers.isEmpty, keyCode == Self.escapeKeyCode {
            return .cancel
        }
        if modifiers.isEmpty, keyCode == Self.deleteKeyCode {
            state = .waiting
            return .clear
        }
        let shortcut = Shortcut(keyCode: UInt32(keyCode), modifiers: modifiers)
        let chord = HotkeyCapture.chord(shortcut, keyName: keyName)
        state = findConflict(shortcut).map { .conflict(chord, owner: $0) } ?? .captured(chord)
        return .recorded
    }

    public mutating func modifierDown(_ key: ModifierKey) {
        heldModifiers.insert(key)
        tappedModifier = heldModifiers.count == 1 ? key : nil
    }

    public mutating func modifierUp(_ key: ModifierKey) {
        heldModifiers.remove(key)
        if tappedModifier == key {
            tappedModifier = nil
            state = .captured(.modifierTap(key))
        }
    }

    public mutating func releaseAllModifiers() {
        heldModifiers = []
        tappedModifier = nil
    }
}
