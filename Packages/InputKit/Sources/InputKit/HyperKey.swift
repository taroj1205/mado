public import AppCore
import Carbon.HIToolbox
public import CoreGraphics

public struct HyperKey {
    enum Action: Equatable {
        case pass
        case addModifiers
        case swallow
        case tap
    }

    static let types: [CGEventType] = [
        .keyDown, .keyUp, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown,
    ]
    static let keyCode = Int64(kVK_F18)
    private static let flags: CGEventFlags = [
        .maskControl, .maskAlternate, .maskShift, .maskCommand,
    ]

    private let isTapped: Bool
    private let window: Duration
    private var pressedAt: CGEventTimestamp?
    private var isUsed = false

    init(isTapped: Bool, window: Duration) {
        self.isTapped = isTapped
        self.window = window
    }

    @MainActor
    public static func install(
        name: String, context: ModuleContext, onTap: (@MainActor (CGEventFlags) -> Void)?
    ) throws(ModuleError) {
        let swallow = swallow(onTap) { [weak context] tap in
            context?.run("\(name) tap", operation: tap)
        }
        try context.tapEvents(name, matching: types, swallow: swallow)
    }

    @MainActor
    static func swallow(
        _ onTap: (@MainActor (CGEventFlags) -> Void)?,
        run: @escaping @MainActor (@escaping @MainActor @Sendable () async -> Void) -> Void
    ) -> @MainActor (CGEventType, CGEvent) -> Bool {
        var key = Self(isTapped: onTap != nil, window: ModifierTap.defaultWindow)
        return { type, event in
            guard !CapsLockTap.isPosted(event) else { return false }
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

            case .tap:
                let held = event.flags.intersection(Self.flags)
                run {
                    guard !Task.isCancelled else { return }
                    onTap?(held)
                }
                return true
            }
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
        guard isTapped, !isUsed, let pressedAt, timestamp >= pressedAt,
            .nanoseconds(timestamp - pressedAt) <= window
        else {
            return .swallow
        }
        return .tap
    }
}
