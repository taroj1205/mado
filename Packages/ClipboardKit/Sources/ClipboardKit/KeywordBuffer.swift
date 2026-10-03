import Carbon.HIToolbox
import CoreGraphics

struct KeywordBuffer: Sendable {
    enum Key: Equatable, Sendable {
        case text(String)
        case deleteBackward
        case other
    }

    private static let privateKeys: ClosedRange<UInt32> = 0xF700...0xF8FF
    private static let maxCharacters = 8

    private(set) var typed: String

    init() {
        typed = ""
    }

    static func key(for event: CGEvent) -> Key? {
        if !event.flags.isDisjoint(with: [.maskCommand, .maskControl]) {
            return .other
        }
        if event.getIntegerValueField(.keyboardEventKeycode) == kVK_Delete {
            return event.flags.contains(.maskAlternate) ? .other : .deleteBackward
        }
        var length = 0
        var characters = [UniChar](repeating: 0, count: maxCharacters)
        unsafe event.keyboardGetUnicodeString(
            maxStringLength: maxCharacters, actualStringLength: &length,
            unicodeString: &characters)
        guard length > 0 else { return nil }
        let text = String(decoding: characters.prefix(length), as: UTF16.self)
        let typesText = text.unicodeScalars.allSatisfy { scalar in
            scalar.properties.generalCategory != .control && !privateKeys.contains(scalar.value)
        }
        return typesText ? .text(text) : .other
    }

    mutating func handle(_ key: Key, keywords: [String]) -> String? {
        switch key {
        case .text(let text):
            typed += text

        case .deleteBackward:
            typed = String(typed.dropLast())
            return nil

        case .other:
            reset()
            return nil
        }
        let longest = keywords.map(\.count).max() ?? 0
        typed = String(typed.suffix(longest))
        let matched = keywords.filter { !$0.isEmpty && typed.hasSuffix($0) }
            .max { $0.count < $1.count }
        if matched != nil {
            reset()
        }
        return matched
    }

    mutating func reset() {
        typed = ""
    }
}
