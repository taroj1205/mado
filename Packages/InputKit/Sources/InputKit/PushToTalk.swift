public import AppCore
import CoreGraphics
import Dispatch

public struct PushToTalk {
    public enum Event: Equatable, Sendable {
        case cancel
        case start
        case stop
    }

    private enum State {
        case idle
        case held(since: CGEventTimestamp)
        case latched
        case waitingForRelease
    }

    static let types: [CGEventType] = [
        .flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown,
    ]

    private let key: ModifierTap.Key
    private let window: Duration
    private var state = State.idle

    init(key: ModifierTap.Key, window: Duration) {
        self.key = key
        self.window = window
    }

    @MainActor
    public static func install(
        _ key: ModifierTap.Key, name: String, context: ModuleContext,
        window: Duration = ModifierTap.defaultWindow,
        onEvent: @escaping @MainActor (Event) -> Void
    ) throws(ModuleError) {
        try context.observeEvents(
            name, matching: types, observe: observe(key, window: window, onEvent: onEvent))
    }

    @MainActor
    static func observe(
        _ key: ModifierTap.Key, window: Duration, onEvent: @escaping @MainActor (Event) -> Void
    ) -> @MainActor (CGEventType, CGEvent) -> Void {
        var machine = Self(key: key, window: window)
        return { type, event in
            let change = machine.handle(
                type, flags: event.flags,
                keyCode: event.getIntegerValueField(.keyboardEventKeycode),
                timestamp: event.timestamp)
            if let change {
                DispatchQueue.main.async { onEvent(change) }
            }
        }
    }

    mutating func handle(
        _ type: CGEventType, flags: CGEventFlags, keyCode: Int64, timestamp: CGEventTimestamp
    ) -> Event? {
        let held = ModifierTap.Key.allCases.filter { flags.rawValue & $0.flag != 0 }
        let alone = type == .flagsChanged && keyCode == key.keyCode && held == [key]
        let released = !held.contains(key)
        switch state {
        case .idle:
            guard alone else { return nil }
            state = .held(since: timestamp)
            return .start

        case .held(let since):
            if type == .flagsChanged, keyCode == key.keyCode, released {
                let quick = timestamp >= since && .nanoseconds(timestamp - since) <= window
                state = quick ? .latched : .idle
                return quick ? nil : .stop
            }
            state = released ? .idle : .waitingForRelease
            return .cancel

        case .latched:
            guard alone else { return nil }
            state = .waitingForRelease
            return .stop

        case .waitingForRelease:
            if released {
                state = .idle
            }
            return nil
        }
    }
}
