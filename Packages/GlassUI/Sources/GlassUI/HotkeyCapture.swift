public import AppCore
import Carbon.HIToolbox

public enum HotkeyCapture: Hashable, Sendable {
    case chord(Shortcut, keyName: String)
    case modifierTap(ModifierKey)

    private static let modifierSymbols: [(Shortcut.Modifiers, String)] = [
        (.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘"),
    ]

    private static let specialKeyNames: [Int: String] = [
        kVK_Return: "Return", kVK_Tab: "Tab", kVK_Space: "Space", kVK_Delete: "⌫",
        kVK_Escape: "Esc", kVK_ANSI_KeypadClear: "Clear", kVK_ANSI_KeypadEnter: "Enter",
        kVK_ForwardDelete: "⌦", kVK_Home: "Home", kVK_End: "End", kVK_PageUp: "Page Up",
        kVK_PageDown: "Page Down", kVK_LeftArrow: "←", kVK_RightArrow: "→",
        kVK_DownArrow: "↓", kVK_UpArrow: "↑", kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3",
        kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9",
        kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    public var keyCaps: [String] {
        switch self {
        case let .chord(shortcut, keyName):
            Self.modifierSymbols.filter { shortcut.modifiers.contains($0.0) }.map(\.1) + [keyName]

        case let .modifierTap(key):
            [key.label]
        }
    }

    public static func keyName(keyCode: UInt16, characters: String?) -> String {
        if let name = specialKeyNames[Int(keyCode)] {
            return name
        }
        guard let characters, !characters.isEmpty else {
            return "Key \(keyCode)"
        }
        return characters.uppercased()
    }
}
