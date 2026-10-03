import CoreGraphics

@MainActor
enum Keystrokes {
    static let marker: Int64 = 0x6D61_646F
    static let arrowFlags: CGEventFlags = [.maskSecondaryFn, .maskNumericPad]
    private static let chunkLength = 20

    static func isPosted(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == marker
    }

    static func press(_ key: CGKeyCode, flags: CGEventFlags, times: Int) throws -> [CGEvent] {
        let source = Self.source()
        let keyDowns = Array(repeating: [true, false], count: max(times, 0)).flatMap(\.self)
        let events = keyDowns.compactMap { down in
            let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down)
            event?.flags = flags
            event?.setIntegerValueField(.eventSourceUserData, value: marker)
            return event
        }
        guard events.count == keyDowns.count else { throw PasteTarget.Failure.noKeyEvents }
        return events
    }

    static func typing(_ text: String) throws -> [CGEvent] {
        let source = Self.source()
        var chunks: [[UniChar]] = []
        for character in text {
            let units = Array(character.utf16)
            if let last = chunks.last, last.count + units.count <= chunkLength {
                chunks[chunks.count - 1] += units
            } else {
                chunks.append(units)
            }
        }
        let keyDowns = chunks.flatMap { [($0, true), ($0, false)] }
        let events = keyDowns.compactMap { units, down in
            let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down)
            event?.flags = []
            unsafe event?.keyboardSetUnicodeString(
                stringLength: units.count, unicodeString: units)
            event?.setIntegerValueField(.eventSourceUserData, value: marker)
            return event
        }
        guard events.count == keyDowns.count else { throw PasteTarget.Failure.noKeyEvents }
        return events
    }

    static func post(_ events: [CGEvent]) {
        for event in events {
            event.post(tap: .cghidEventTap)
        }
    }

    private static func source() -> CGEventSource? {
        let source = CGEventSource(stateID: .hidSystemState)
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval)
        return source
    }
}
