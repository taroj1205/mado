public import AppCore
import Carbon.HIToolbox
import CoreGraphics
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

    public struct Tap: Hashable, Sendable {
        public let keys: Set<Key>
        public let count: Int

        public init(_ key: Key, count: Int = 1) {
            self.init(keys: [key], count: count)
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
        private let run: @MainActor (@escaping @MainActor @Sendable () async -> Void) -> Void
        private var tap: ModifierTap
        private var waits = 0

        init(
            window: Duration, bindings: [Tap: @MainActor () -> Void],
            run: @escaping @MainActor (@escaping @MainActor @Sendable () async -> Void) -> Void
        ) {
            self.window = window
            self.bindings = bindings
            self.run = run
            tap = ModifierTap(window: window, bound: Set(bindings.keys))
        }

        func handle(_ type: CGEventType, _ event: CGEvent) {
            let previous = tap.held
            let fired = tap.handle(
                type, flags: event.flags,
                keyCode: event.getIntegerValueField(.keyboardEventKeycode),
                timestamp: event.timestamp)
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

    public static let defaultWindow: Duration = .milliseconds(defaultWindowMilliseconds)

    static let types: [CGEventType] = [
        .flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown,
    ]

    private let window: Duration
    private let bound: Set<Tap>
    private var pressed: (keys: Set<Key>, since: CGEventTimestamp)?
    private var streak: (last: Tap, releasedAt: CGEventTimestamp)?
    private(set) var held: Tap?

    init(window: Duration, bound: Set<Tap>) {
        self.window = window
        self.bound = bound
    }

    @MainActor
    public static func install(
        name: String, context: ModuleContext, bindings: [Tap: @MainActor () -> Void],
        window: Duration = defaultWindow
    ) throws(ModuleError) {
        let recognizer = Recognizer(window: window, bindings: bindings) { [weak context] wait in
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
        streak =
            bound.contains { $0.keys == tap.keys && $0.count > tap.count } ? (tap, timestamp) : nil
        guard bound.contains(tap), bound.contains(Tap(keys: tap.keys, count: tap.count + 1)) else {
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
