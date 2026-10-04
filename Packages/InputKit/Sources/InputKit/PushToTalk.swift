public import AppCore
import CoreGraphics
import Dispatch

public struct PushToTalk {
    public enum Event: Equatable, Sendable {
        case started
        case toggled
        case stopped
        case cancelled
    }

    private enum State {
        case idle
        case held(since: CGEventTimestamp)
        case toggled
    }

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
        isActive: @escaping @MainActor () -> Bool,
        onEvent: @escaping @MainActor (Event) -> Void
    ) throws(ModuleError) {
        try context.observeEvents(
            name, matching: ModifierTap.types,
            observe: observe(key, window: window, isActive: isActive, onEvent: onEvent))
    }

    @MainActor
    static func observe(
        _ key: ModifierTap.Key, window: Duration, isActive: @escaping @MainActor () -> Bool,
        onEvent: @escaping @MainActor (Event) -> Void
    ) -> @MainActor (CGEventType, CGEvent) -> Void {
        var talk = Self(key: key, window: window)
        return { type, event in
            let change = talk.handle(
                type, flags: event.flags,
                keyCode: event.getIntegerValueField(.keyboardEventKeycode),
                timestamp: event.timestamp, isActive: isActive())
            if let change {
                DispatchQueue.main.async { onEvent(change) }
            }
        }
    }

    mutating func handle(
        _ type: CGEventType, flags: CGEventFlags, keyCode: Int64, timestamp: CGEventTimestamp,
        isActive: Bool
    ) -> Event? {
        let held = ModifierTap.Key.allCases.filter { flags.rawValue & $0.flag != 0 }
        let pressed = type == .flagsChanged && keyCode == key.keyCode && held.contains(key)
        switch state {
        case .toggled where isActive:
            guard pressed else { return nil }
            state = .idle
            return .stopped

        case .idle, .toggled:
            guard pressed, held == [key] else {
                state = .idle
                return nil
            }
            state = .held(since: timestamp)
            return .started

        case .held(let since):
            if type == .flagsChanged, held == [key] {
                return nil
            }
            guard type == .flagsChanged, held.isEmpty else {
                state = .idle
                return .cancelled
            }
            let isTap = timestamp >= since && .nanoseconds(timestamp - since) <= window
            state = isTap ? .toggled : .idle
            return isTap ? .toggled : .stopped
        }
    }
}
