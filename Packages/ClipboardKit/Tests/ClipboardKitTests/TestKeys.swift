import CoreGraphics
import Testing

enum TestKeys {
    static func event(_ code: Int, _ text: String, _ flags: CGEventFlags) throws -> CGEvent {
        let event = try #require(
            CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: true))
        let units = Array(text.utf16)
        unsafe event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
        event.flags = flags
        return event
    }
}
