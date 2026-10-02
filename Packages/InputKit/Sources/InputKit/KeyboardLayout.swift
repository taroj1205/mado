import Carbon.HIToolbox
public import CoreGraphics
import Foundation

@MainActor
public enum KeyboardLayout {
    private static let keyCodeCount: UInt16 = 128
    private static let maxLength = 4
    private static let modifierShift = 8
    private static let modifierMask = 0xFF

    public static func commandKeyCode(typing character: String) -> CGKeyCode? {
        guard let source = unsafe TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue()
        else { return nil }
        return commandKeyCode(typing: character, in: source)
    }

    static func commandKeyCode(typing character: String, in source: TISInputSource) -> CGKeyCode? {
        guard let raw = unsafe TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let data = unsafe Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        let command = UInt32((cmdKey >> modifierShift) & modifierMask)
        let keyboard = UInt32(LMGetKbdType())
        return unsafe data.withUnsafeBytes { bytes in
            guard let layout = unsafe bytes.bindMemory(to: UCKeyboardLayout.self).baseAddress
            else { return nil }
            return (0..<keyCodeCount).first { code in
                var deadKeys: UInt32 = 0
                var length = 0
                var characters = [UniChar](repeating: 0, count: maxLength)
                let status = unsafe UCKeyTranslate(
                    layout, code, UInt16(kUCKeyActionDown), command, keyboard,
                    OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeys, maxLength, &length,
                    &characters)
                return status == noErr
                    && String(decoding: characters.prefix(length), as: UTF16.self) == character
            }
        }
    }
}
