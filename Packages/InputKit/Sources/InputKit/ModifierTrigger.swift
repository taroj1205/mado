public import AppCore
import Carbon.HIToolbox
import CoreGraphics
import Dispatch

public struct ModifierTrigger {
    public enum Event: Equatable, Sendable {
        case cancelled
        case clicked
        case pressed
        case released
    }

    static let types: [CGEventType] = [
        .flagsChanged, .leftMouseDown, .leftMouseDragged, .leftMouseUp, .keyDown, .keyUp,
    ]
    private static let modifierFlags: CGEventFlags = [
        .maskCommand, .maskControl, .maskAlternate, .maskShift,
    ]
    private static let escape = Int64(kVK_Escape)

    private let modifiers: CGEventFlags
    private var isHeld = false
    private var isOpen = false
    private var swallowsClickUp = false
    private var swallowsEscapeUp = false

    init(modifiers: Shortcut.Modifiers) {
        self.modifiers = Self.eventFlags(modifiers)
    }

    @MainActor
    public static func install(
        _ modifiers: Shortcut.Modifiers, name: String, context: ModuleContext,
        onEvent: @escaping @MainActor (Event) -> Void
    ) throws(ModuleError) {
        try context.tapEvents(name, matching: types, swallow: swallow(modifiers, onEvent: onEvent))
    }

    @MainActor
    static func swallow(
        _ modifiers: Shortcut.Modifiers, onEvent: @escaping @MainActor (Event) -> Void
    ) -> @MainActor (CGEventType, CGEvent) -> Bool {
        var trigger = Self(modifiers: modifiers)
        return { type, event in
            trigger.handle(
                type, flags: event.flags,
                keyCode: event.getIntegerValueField(.keyboardEventKeycode)
            ) { change in
                DispatchQueue.main.async { onEvent(change) }
            }
        }
    }

    private static func eventFlags(_ modifiers: Shortcut.Modifiers) -> CGEventFlags {
        var result: CGEventFlags = []
        if modifiers.contains(.command) { result.insert(.maskCommand) }
        if modifiers.contains(.control) { result.insert(.maskControl) }
        if modifiers.contains(.option) { result.insert(.maskAlternate) }
        if modifiers.contains(.shift) { result.insert(.maskShift) }
        return result
    }

    mutating func handle(
        _ type: CGEventType, flags: CGEventFlags, keyCode: Int64, emit: (Event) -> Void
    ) -> Bool {
        track(flags, emit: emit)
        switch type {
        case .leftMouseDown where isOpen:
            swallowsClickUp = true
            emit(.clicked)
            return true

        case .leftMouseDragged where swallowsClickUp:
            return true

        case .leftMouseUp where swallowsClickUp:
            swallowsClickUp = false
            return true

        case .keyDown where keyCode == Self.escape && (isOpen || swallowsEscapeUp):
            swallowsEscapeUp = true
            if isOpen {
                isOpen = false
                emit(.cancelled)
            }
            return true

        case .keyUp where keyCode == Self.escape && swallowsEscapeUp:
            swallowsEscapeUp = false
            return true

        default:
            return false
        }
    }

    private mutating func track(_ flags: CGEventFlags, emit: (Event) -> Void) {
        let held = !modifiers.isEmpty && flags.intersection(Self.modifierFlags) == modifiers
        guard held != isHeld else { return }
        isHeld = held
        if held {
            emit(.pressed)
        } else if isOpen {
            emit(.released)
        }
        isOpen = held
    }
}
