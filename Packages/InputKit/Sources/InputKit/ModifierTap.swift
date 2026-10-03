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

    public enum Tap: Hashable, Sendable {
        case single(Key)
        case double(Key)
        case triple(Key)

        var next: Self? {
            switch self {
            case .single(let key): .double(key)
            case .double(let key): .triple(key)
            case .triple: nil
            }
        }
    }

    private struct Run {
        let key: Key
        let tap: Tap
        let releasedAt: CGEventTimestamp
        let waits: Bool
    }

    @MainActor
    private final class Detector {
        private var state: ModifierTap
        private let window: Duration
        private let actions: [Tap: @MainActor () -> Void]

        init(window: Duration, actions: [Tap: @MainActor () -> Void]) {
            state = ModifierTap(window: window, bindings: Set(actions.keys))
            self.window = window
            self.actions = actions
        }

        func handle(_ type: CGEventType, _ event: CGEvent) {
            let fired = state.handle(
                type, flags: event.flags,
                keyCode: event.getIntegerValueField(.keyboardEventKeycode),
                timestamp: event.timestamp)
            if let fired, let action = actions[fired] {
                DispatchQueue.main.async { action() }
            }
            guard let releasedAt = state.waitingSince, releasedAt == event.timestamp else {
                return
            }
            Task { [weak self, window] in
                try? await Task.sleep(for: window)
                guard let self, let expired = state.expire(releasedAt: releasedAt) else { return }
                actions[expired]?()
            }
        }
    }

    private static let defaultWindowMilliseconds = 300

    public static let defaultWindow: Duration = .milliseconds(defaultWindowMilliseconds)

    static let types: [CGEventType] = [
        .flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown,
    ]

    private let window: Duration
    private let bindings: Set<Tap>
    private var press: (key: Key, since: CGEventTimestamp)?
    private var run: Run?

    var waitingSince: CGEventTimestamp? {
        guard let run, run.waits else { return nil }
        return run.releasedAt
    }

    init(window: Duration, bindings: Set<Tap>) {
        self.window = window
        self.bindings = bindings
    }

    @MainActor
    public static func install(
        name: String, context: ModuleContext, bindings: [Tap: @MainActor () -> Void],
        window: Duration = defaultWindow
    ) throws(ModuleError) {
        try context.observeEvents(
            name, matching: types, observe: observe(window: window, bindings: bindings))
    }

    @MainActor
    static func observe(
        window: Duration, bindings: [Tap: @MainActor () -> Void]
    ) -> @MainActor (CGEventType, CGEvent) -> Void {
        let detector = Detector(window: window, actions: bindings)
        return { type, event in detector.handle(type, event) }
    }

    mutating func handle(
        _ type: CGEventType, flags: CGEventFlags, keyCode: Int64, timestamp: CGEventTimestamp
    ) -> Tap? {
        let previous = press
        press = nil
        guard type == .flagsChanged,
            let key = Key.allCases.first(where: { $0.keyCode == keyCode })
        else {
            return flush()
        }
        let held = Key.allCases.filter { flags.rawValue & $0.flag != 0 }
        if held == [key] {
            let continues = run.map { $0.key == key && within($0.releasedAt, timestamp) } ?? false
            let flushed = continues ? nil : flush()
            press = (key, timestamp)
            return flushed
        }
        guard held.isEmpty, let previous, previous.key == key, within(previous.since, timestamp)
        else {
            return flush()
        }
        return release(key, at: timestamp)
    }

    mutating func expire(releasedAt: CGEventTimestamp) -> Tap? {
        guard press == nil, run?.releasedAt == releasedAt else { return nil }
        return flush()
    }

    private mutating func release(_ key: Key, at timestamp: CGEventTimestamp) -> Tap? {
        let tap = run?.tap.next ?? .single(key)
        let waits = isBound(tap) && isBound(tap.next)
        let canGoOn = isBound(tap.next) || isBound(tap.next?.next)
        run = canGoOn ? Run(key: key, tap: tap, releasedAt: timestamp, waits: waits) : nil
        return isBound(tap) && !waits ? tap : nil
    }

    private func isBound(_ tap: Tap?) -> Bool {
        tap.map(bindings.contains) ?? false
    }

    private mutating func flush() -> Tap? {
        defer { run = nil }
        guard let run, run.waits else { return nil }
        return run.tap
    }

    private func within(_ start: CGEventTimestamp, _ end: CGEventTimestamp) -> Bool {
        end >= start && .nanoseconds(end - start) <= window
    }
}
