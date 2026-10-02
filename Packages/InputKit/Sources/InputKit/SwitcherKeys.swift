public import AppCore
import Carbon.HIToolbox
import CoreGraphics
import Dispatch

public struct SwitcherKeys {
    public enum Event: Equatable, Sendable {
        case pressed(keyCode: Int64)
        case stepped(backward: Bool)
        case chosen
        case cancelled
    }

    struct Key {
        let code: Int64
        let isRepeat: Bool
    }

    static let types: [CGEventType] = [.flagsChanged, .keyDown, .keyUp]
    private static let tab = Int64(kVK_Tab)
    private static let escape = Int64(kVK_Escape)

    private var swallowedDowns: Set<Int64> = []

    @MainActor
    public static func install(
        name: String, context: ModuleContext, isOpen: @escaping @MainActor () -> Bool,
        onEvent: @escaping @MainActor (Event) -> Void
    ) throws(ModuleError) {
        try context.tapEvents(
            name, matching: types, swallow: swallow(isOpen: isOpen, onEvent: onEvent))
    }

    @MainActor
    static func swallow(
        isOpen: @escaping @MainActor () -> Bool, onEvent: @escaping @MainActor (Event) -> Void
    ) -> @MainActor (CGEventType, CGEvent) -> Bool {
        var keys = Self()
        return { type, event in
            keys.handle(
                type, flags: event.flags,
                key: Key(
                    code: event.getIntegerValueField(.keyboardEventKeycode),
                    isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0),
                isOpen: isOpen()
            ) { change in
                DispatchQueue.main.async { onEvent(change) }
            }
        }
    }

    mutating func handle(
        _ type: CGEventType, flags: CGEventFlags, key: Key, isOpen: Bool, emit: (Event) -> Void
    ) -> Bool {
        if type == .keyUp {
            return swallowedDowns.remove(key.code) != nil
        }
        guard isOpen else { return false }
        guard flags.contains(.maskAlternate) else {
            emit(.chosen)
            return false
        }
        guard type == .keyDown else { return false }
        guard key.code != Self.tab else {
            if key.isRepeat { emit(.stepped(backward: flags.contains(.maskShift))) }
            return key.isRepeat
        }
        emit(key.code == Self.escape ? .cancelled : .pressed(keyCode: key.code))
        swallowedDowns.insert(key.code)
        return true
    }
}
