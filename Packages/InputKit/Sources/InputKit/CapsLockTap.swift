public import AppCore
import Carbon.HIToolbox
public import CoreGraphics
import IOKit
import IOKit.hidsystem
import os

public enum CapsLockTap: Equatable, Sendable {
    case capsLock
    case escape
    case openMado
    case shortcut(Shortcut)

    static let marker: Int64 = 0x4D61_646F

    private static let logger = Log.logger("keyboard")

    static func isPosted(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == marker
    }

    static func keyStrokes(_ key: CGKeyCode, flags: CGEventFlags) -> [CGEvent] {
        [true, false].compactMap { isDown in
            let event = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: isDown)
            event?.flags = flags
            event?.setIntegerValueField(.eventSourceUserData, value: marker)
            return event
        }
    }

    private static func toggleCapsLock() {
        let system = unsafe IOServiceGetMatchingService(
            kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        defer { IOObjectRelease(system) }
        var connection: io_connect_t = 0
        guard
            unsafe IOServiceOpen(
                system, mach_task_self_, UInt32(kIOHIDParamConnectType), &connection)
                == KERN_SUCCESS
        else {
            logger.error("Caps Lock can't be reached")
            return
        }
        defer { IOServiceClose(connection) }
        var isOn = false
        let selector = Int32(kIOHIDCapsLockState)
        guard unsafe IOHIDGetModifierLockState(connection, selector, &isOn) == KERN_SUCCESS,
            IOHIDSetModifierLockState(connection, selector, !isOn) == KERN_SUCCESS
        else {
            logger.error("Caps Lock can't be toggled")
            return
        }
    }

    @MainActor
    public func perform(holding flags: CGEventFlags, openMado: @MainActor () -> Void) {
        guard !IsSecureEventInputEnabled() else { return }
        switch self {
        case .escape:
            Self.keyStrokes(CGKeyCode(kVK_Escape), flags: flags)
                .forEach { $0.post(tap: .cgSessionEventTap) }

        case .capsLock:
            Self.toggleCapsLock()

        case .openMado:
            openMado()

        case .shortcut(let shortcut):
            Self.keyStrokes(
                CGKeyCode(truncatingIfNeeded: shortcut.keyCode),
                flags: ModifierTrigger.eventFlags(shortcut.modifiers)
            )
            .forEach { $0.post(tap: .cgSessionEventTap) }
        }
    }
}
