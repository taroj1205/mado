public import AppCore
import Carbon.HIToolbox
import CoreGraphics
import IOKit.hidsystem

public struct ModifierTap {
    public enum Key: String, Codable, CaseIterable, Sendable {
        case leftCommand = "left_command"
        case rightCommand = "right_command"
        case leftShift = "left_shift"
        case rightShift = "right_shift"
        case leftOption = "left_option"
        case rightOption = "right_option"
        case leftControl = "left_control"
        case rightControl = "right_control"
        case function = "function"

        public var modifierKey: HotKey.ModifierKey? {
            switch self {
            case .leftCommand: .leftCommand
            case .rightCommand: .rightCommand
            case .leftShift: .leftShift
            case .rightShift: .rightShift
            case .leftOption: .leftOption
            case .rightOption: .rightOption
            case .leftControl: .leftControl
            case .rightControl: .rightControl
            case .function: nil
            }
        }

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

    public struct Tap: Hashable, Sendable {
        public let keys: Set<Key>
        public let count: Int

        public init(_ key: Key, count: Int = 1) {
            self.init(keys: [key], count: count)
        }

        public init(_ key: HotKey.ModifierKey) {
            let tapped: Key =
                switch key {
                case .leftCommand: .leftCommand
                case .rightCommand: .rightCommand
                case .leftShift: .leftShift
                case .rightShift: .rightShift
                case .leftOption: .leftOption
                case .rightOption: .rightOption
                case .leftControl: .leftControl
                case .rightControl: .rightControl
                }
            self.init(tapped)
        }

        public init(_ first: Key, _ second: Key) {
            self.init(keys: [first, second], count: 1)
        }

        init(keys: Set<Key>, count: Int) {
            self.keys = keys
            self.count = count
        }
    }

    @MainActor
    final class Recognizer {
        private let window: Duration
        private let bindings: [Tap: @MainActor () -> Void]
        private let mouseButtonHeld: () -> Bool
        private let run: @MainActor (@escaping @MainActor @Sendable () async -> Void) -> Void
        private var tap: ModifierTap
        private var heldKeys: Set<Int64> = []
        private var waits = 0

        init(
            window: Duration, bindings: [Tap: @MainActor () -> Void],
            mouseButtonHeld: @escaping () -> Bool,
            run: @escaping @MainActor (@escaping @MainActor @Sendable () async -> Void) -> Void
        ) {
            self.window = window
            self.bindings = bindings
            self.mouseButtonHeld = mouseButtonHeld
            self.run = run
            tap = ModifierTap(window: window, bound: Set(bindings.keys))
        }

        func handle(_ type: CGEventType, _ event: CGEvent) {
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            switch type {
            case .keyUp:
                heldKeys.remove(code)
                return

            case .keyDown:
                heldKeys.insert(code)

            default:
                break
            }
            let previous = tap.held
            let interrupted = type == .flagsChanged && (!heldKeys.isEmpty || mouseButtonHeld())
            let fired = tap.handle(
                interrupted ? .keyDown : type, flags: event.flags,
                keyCode: code, timestamp: event.timestamp)
            if let fired, bindings[fired] != nil {
                run { [weak self] in
                    guard !Task.isCancelled else { return }
                    self?.bindings[fired]?()
                }
            }
            guard tap.held != nil, tap.held != previous else { return }
            waits += 1
            let current = waits
            run { [weak self, window] in
                try? await Task.sleep(for: window)
                guard !Task.isCancelled, let self, current == waits, let expired = tap.expire()
                else {
                    return
                }
                bindings[expired]?()
            }
        }
    }

    private static let defaultWindowMilliseconds = 300
    private static let mouseButtonCount: UInt32 = 32

    public static let defaultWindow: Duration = .milliseconds(defaultWindowMilliseconds)

    static let systemDefined = CGEventType(rawValue: UInt32(NX_SYSDEFINED))

    static let types: [CGEventType] =
        [
            .flagsChanged, .keyDown, .keyUp, .leftMouseDown, .rightMouseDown, .otherMouseDown,
            .scrollWheel,
        ] + [systemDefined].compactMap(\.self)

    private let window: Duration
    private let bound: Set<Tap>
    private var pressed: (keys: Set<Key>, since: CGEventTimestamp)?
    private var streak: (last: Tap, releasedAt: CGEventTimestamp)?
    private(set) var held: Tap?

    init(window: Duration, bound: Set<Tap>) {
        self.window = window
        self.bound = bound
    }

    private static func mouseButtonIsDown() -> Bool {
        (0..<mouseButtonCount).contains { number in
            guard let button = CGMouseButton(rawValue: number) else { return false }
            return CGEventSource.buttonState(.combinedSessionState, button: button)
        }
    }

    @MainActor
    public static func install(
        name: String, context: ModuleContext, bindings: [Tap: @MainActor () -> Void],
        window: Duration = defaultWindow
    ) throws(ModuleError) {
        let recognizer = Recognizer(
            window: window, bindings: bindings, mouseButtonHeld: mouseButtonIsDown
        ) { [weak context] wait in
            context?.run("\(name) window", operation: wait)
        }
        try context.observeEvents(name, matching: types, observe: recognizer.handle)
    }

    mutating func handle(
        _ type: CGEventType, flags: CGEventFlags, keyCode: Int64, timestamp: CGEventTimestamp
    ) -> Tap? {
        let press = pressed
        pressed = nil
        guard type == .flagsChanged, let key = Key.allCases.first(where: { $0.keyCode == keyCode })
        else {
            return flush()
        }
        let down = Set(Key.allCases.filter { flags.rawValue & $0.flag != 0 })
        if down == [key] {
            pressed = ([key], timestamp)
            if let streak, streak.last.keys == [key], within(streak.releasedAt, timestamp) {
                return nil
            }
            return flush()
        }
        guard let press else { return flush() }
        if press.keys.count == 1, !press.keys.contains(key), down == press.keys.union([key]) {
            pressed = (down, press.since)
            return flush()
        }
        if press.keys.count > 1, press.keys.contains(key), down == press.keys.subtracting([key]) {
            pressed = press
            return nil
        }
        guard down.isEmpty, press.keys.contains(key), within(press.since, timestamp) else {
            return flush()
        }
        let tap = Tap(keys: press.keys, count: (streak?.last.count ?? 0) + 1)
        held = nil
        let repeats = bound.contains { $0.keys == tap.keys && $0.count > tap.count }
        streak = repeats ? (tap, timestamp) : nil
        guard bound.contains(tap), repeats else {
            return tap
        }
        held = tap
        return nil
    }

    mutating func expire() -> Tap? {
        pressed == nil ? flush() : nil
    }

    private mutating func flush() -> Tap? {
        let waiting = held
        held = nil
        streak = nil
        return waiting
    }

    private func within(_ start: CGEventTimestamp, _ end: CGEventTimestamp) -> Bool {
        end >= start && .nanoseconds(end - start) <= window
    }
}
