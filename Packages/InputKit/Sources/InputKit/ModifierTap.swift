public import AppCore
import Carbon.HIToolbox
import CoreGraphics
import Dispatch
import IOKit.hidsystem

public struct ModifierTap {
    public enum Key: CaseIterable, Sendable {
        case leftCommand
        case rightCommand
        case leftShift
        case rightShift
        case leftOption
        case rightOption
        case leftControl
        case rightControl
        case function

        var keyCode: Int64 {
            switch self {
            case .leftCommand: Int64(kVK_Command)
            case .rightCommand: Int64(kVK_RightCommand)
            case .leftShift: Int64(kVK_Shift)
            case .rightShift: Int64(kVK_RightShift)
            case .leftOption: Int64(kVK_Option)
            case .rightOption: Int64(kVK_RightOption)
            case .leftControl: Int64(kVK_Control)
            case .rightControl: Int64(kVK_RightControl)
            case .function: Int64(kVK_Function)
            }
        }

        var flag: UInt64 {
            switch self {
            case .leftCommand: UInt64(NX_DEVICELCMDKEYMASK)
            case .rightCommand: UInt64(NX_DEVICERCMDKEYMASK)
            case .leftShift: UInt64(NX_DEVICELSHIFTKEYMASK)
            case .rightShift: UInt64(NX_DEVICERSHIFTKEYMASK)
            case .leftOption: UInt64(NX_DEVICELALTKEYMASK)
            case .rightOption: UInt64(NX_DEVICERALTKEYMASK)
            case .leftControl: UInt64(NX_DEVICELCTLKEYMASK)
            case .rightControl: UInt64(NX_DEVICERCTLKEYMASK)
            case .function: CGEventFlags.maskSecondaryFn.rawValue
            }
        }
    }

    private static let defaultWindowMilliseconds = 300

    public static let defaultWindow: Duration = .milliseconds(defaultWindowMilliseconds)

    static let types: [CGEventType] = [
        .flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown,
    ]

    private let window: Duration
    private var pending: (key: Key, since: CGEventTimestamp)?

    init(window: Duration) {
        self.window = window
    }

    @MainActor
    public static func install(
        name: String, context: ModuleContext, window: Duration = defaultWindow,
        onTap: @escaping @MainActor (Key) -> Void
    ) throws(ModuleError) {
        try context.tapEvents(name, matching: types, swallow: observe(window: window, onTap: onTap))
    }

    @MainActor
    static func observe(
        window: Duration, onTap: @escaping @MainActor (Key) -> Void
    ) -> @MainActor (CGEventType, CGEvent) -> Bool {
        var tap = Self(window: window)
        return { type, event in
            let key = tap.handle(
                type, flags: event.flags,
                keyCode: event.getIntegerValueField(.keyboardEventKeycode),
                timestamp: event.timestamp)
            if let key {
                DispatchQueue.main.async { onTap(key) }
            }
            return false
        }
    }

    mutating func handle(
        _ type: CGEventType, flags: CGEventFlags, keyCode: Int64, timestamp: CGEventTimestamp
    ) -> Key? {
        let previous = pending
        pending = nil
        guard type == .flagsChanged,
            let key = Key.allCases.first(where: { $0.keyCode == keyCode })
        else {
            return nil
        }
        let held = Key.allCases.filter { flags.rawValue & $0.flag != 0 }
        if held == [key] {
            pending = (key, timestamp)
            return nil
        }
        guard held.isEmpty, let previous, previous.key == key, timestamp >= previous.since,
            .nanoseconds(timestamp - previous.since) <= window
        else {
            return nil
        }
        return key
    }
}
