public import AppCore
import Carbon.HIToolbox
import CoreGraphics
import Dispatch

public struct SwitcherKeys {
    public enum Event: Equatable, Sendable {
        case pressed(keyCode: Int64)
        case chosen
        case cancelled
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
                keyCode: event.getIntegerValueField(.keyboardEventKeycode), isOpen: isOpen()
            ) { change in
                DispatchQueue.main.async { onEvent(change) }
            }
        }
    }

    mutating func handle(
        _ type: CGEventType, flags: CGEventFlags, keyCode: Int64, isOpen: Bool,
        emit: (Event) -> Void
    ) -> Bool {
        if type == .keyUp {
            return swallowedDowns.remove(keyCode) != nil
        }
        guard isOpen else { return false }
        guard flags.contains(.maskAlternate) else {
            emit(.chosen)
            return false
        }
        guard type == .keyDown, keyCode != Self.tab else { return false }
        emit(keyCode == Self.escape ? .cancelled : .pressed(keyCode: keyCode))
        swallowedDowns.insert(keyCode)
        return true
    }
}
