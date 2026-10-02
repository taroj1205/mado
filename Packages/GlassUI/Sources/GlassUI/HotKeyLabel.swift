import AppCore
import AppKit
import Carbon.HIToolbox

enum HotKeyLabel {
    private static let symbols: [(Shortcut.Modifiers, String)] = [
        (.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘"),
    ]

    private static let specialKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_ANSI_KeypadEnter: "⌤", kVK_Tab: "⇥",
        kVK_Delete: "⌫", kVK_ForwardDelete: "⌦", kVK_Escape: "⎋", kVK_Help: "Help",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_DownArrow: "↓", kVK_UpArrow: "↑",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_JIS_Eisu: "英数", kVK_JIS_Kana: "かな",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12", kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15",
        kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
    ]

    static func keycaps(_ hotKey: HotKey) -> [String] {
        switch hotKey {
        case .shortcut(let shortcut):
            return symbols(shortcut.modifiers) + [keyName(shortcut.keyCode)]

        case .modifierTap(let key):
            let side =
                switch key {
                case .leftCommand, .leftControl, .leftOption, .leftShift: "Left"
                case .rightCommand, .rightControl, .rightOption, .rightShift: "Right"
                }
            return ["\(side) \(symbols(modifier(of: key)).joined())"]
        }
    }

    static func symbols(_ modifiers: Shortcut.Modifiers) -> [String] {
        symbols.filter { modifiers.contains($0.0) }.map(\.1)
    }

    static func modifier(of key: HotKey.ModifierKey) -> Shortcut.Modifiers {
        switch key {
        case .leftCommand, .rightCommand: .command
        case .leftControl, .rightControl: .control
        case .leftOption, .rightOption: .option
        case .leftShift, .rightShift: .shift
        }
    }

    static func keyName(_ keyCode: UInt32) -> String {
        if let name = specialKeys[Int(keyCode)] {
            return name
        }
        let event = CGEvent(
            keyboardEventSource: nil, virtualKey: CGKeyCode(truncatingIfNeeded: keyCode),
            keyDown: true)
        let characters = event.flatMap(NSEvent.init(cgEvent:))?.charactersIgnoringModifiers
        guard let characters, !characters.isEmpty else {
            return "Key \(keyCode)"
        }
        return characters.uppercased()
    }
}
