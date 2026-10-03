public import AppCore
import Carbon.HIToolbox
import CoreGraphics
import Dispatch

public struct HyperKey {
    enum Outcome: Equatable {
        case pass
        case hyper
        case swallow
        case escape
    }

    static let types: [CGEventType] = [
        .keyDown, .keyUp, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown,
    ]
    static let flags: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]
    static let keyCode = Int64(kVK_F18)

    private let tapsEscape: Bool
    private var pressed: CGEventTimestamp?
    private var used = false

    init(tapsEscape: Bool) {
        self.tapsEscape = tapsEscape
    }

    @MainActor
    public static func install(
        name: String, context: ModuleContext, tapsEscape: Bool
    ) throws(ModuleError) {
        var key = Self(tapsEscape: tapsEscape)
        try context.tapEvents(name, matching: types) { type, event in
            let outcome = key.handle(
                type, keyCode: event.getIntegerValueField(.keyboardEventKeycode),
                timestamp: event.timestamp)
            switch outcome {
            case .pass:
                return false

            case .hyper:
                event.flags.formUnion(flags)
                return false

            case .swallow:
                return true

            case .escape:
                DispatchQueue.main.async { postEscape() }
                return true
            }
        }
    }

    private static func postEscape() {
        for isDown in [true, false] {
            let event = CGEvent(
                keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Escape), keyDown: isDown)
            event?.flags = []
            event?.post(tap: .cgSessionEventTap)
        }
    }

    mutating func handle(
        _ type: CGEventType, keyCode: Int64, timestamp: CGEventTimestamp
    ) -> Outcome {
        let isKey = type == .keyDown || type == .keyUp
        if isKey, keyCode == Self.keyCode {
            return press(isDown: type == .keyDown, timestamp: timestamp)
        }
        guard pressed != nil else { return .pass }
        used = true
        return isKey ? .hyper : .pass
    }

    private mutating func press(isDown: Bool, timestamp: CGEventTimestamp) -> Outcome {
        if isDown {
            if pressed == nil {
                pressed = timestamp
                used = false
            }
            return .swallow
        }
        guard let since = pressed else { return .pass }
        pressed = nil
        let isTap =
            tapsEscape && !used && timestamp >= since
            && .nanoseconds(timestamp - since) <= ModifierTap.defaultWindow
        return isTap ? .escape : .pass
    }
}
