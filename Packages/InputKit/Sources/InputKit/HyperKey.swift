public import AppCore
import Carbon.HIToolbox
import CoreGraphics

public struct HyperKey {
    enum Action: Equatable {
        case pass
        case addModifiers
        case swallow
        case sendEscape
    }

    public static let modifiers: Shortcut.Modifiers = [.control, .option, .shift, .command]

    static let types: [CGEventType] = [
        .keyDown, .keyUp, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown,
    ]
    static let keyCode = Int64(kVK_F18)
    private static let flags: CGEventFlags = [
        .maskControl, .maskAlternate, .maskShift, .maskCommand,
    ]

    private let tapSendsEscape: Bool
    private let window: Duration
    private var pressedAt: CGEventTimestamp?
    private var isUsed = false

    init(tapSendsEscape: Bool, window: Duration) {
        self.tapSendsEscape = tapSendsEscape
        self.window = window
    }

    @MainActor
    public static func install(
        name: String, context: ModuleContext, tapSendsEscape: Bool
    ) throws(ModuleError) {
        try context.tapEvents(name, matching: types, swallow: swallow(tapSendsEscape))
    }

    @MainActor
    static func swallow(_ tapSendsEscape: Bool) -> @MainActor (CGEventType, CGEvent) -> Bool {
        var key = Self(tapSendsEscape: tapSendsEscape, window: ModifierTap.defaultWindow)
        return { type, event in
            let action = key.handle(
                type, keyCode: event.getIntegerValueField(.keyboardEventKeycode),
                isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
                timestamp: event.timestamp
            ) {
                CGEventSource.keyState(.hidSystemState, key: CGKeyCode(Self.keyCode))
            }
            switch action {
            case .pass:
                return false

            case .addModifiers:
                event.flags.formUnion(Self.flags)
                return false

            case .swallow:
                return true

            case .sendEscape:
                sendEscape(flags: event.flags.intersection(Self.flags))
                return true
            }
        }
    }

    private static func sendEscape(flags: CGEventFlags) {
        for isDown in [true, false] {
            let event = CGEvent(
                keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Escape), keyDown: isDown)
            event?.flags = flags
            event?.post(tap: .cgSessionEventTap)
        }
    }

    mutating func handle(
        _ type: CGEventType, keyCode: Int64, isRepeat: Bool, timestamp: CGEventTimestamp,
        isHeld: () -> Bool
    ) -> Action {
        if [.keyDown, .keyUp].contains(type), keyCode == Self.keyCode {
            guard type == .keyDown else { return release(at: timestamp) }
            if !isRepeat {
                pressedAt = timestamp
                isUsed = false
            }
            return .swallow
        }
        guard pressedAt != nil else { return .pass }
        guard isHeld() else {
            pressedAt = nil
            return .pass
        }
        isUsed = true
        return type == .keyDown ? .addModifiers : .pass
    }

    private mutating func release(at timestamp: CGEventTimestamp) -> Action {
        defer { pressedAt = nil }
        guard tapSendsEscape, !isUsed, let pressedAt, timestamp >= pressedAt,
            .nanoseconds(timestamp - pressedAt) <= window
        else {
            return .swallow
        }
        return .sendEscape
    }
}
