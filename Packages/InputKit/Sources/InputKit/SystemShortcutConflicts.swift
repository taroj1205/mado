public import AppCore
import Foundation

public enum SystemShortcutConflicts {
    private struct Binding {
        let id: String
        let conflict: HotKeyConflict
        let defaultShortcut: Shortcut
    }

    private static let keyCodeIndex = 1
    private static let flagsIndex = 2
    private static let spaceKeyCode: UInt32 = 49
    private static let commandFlag = 0x10_0000
    private static let optionFlag = 0x8_0000
    private static let controlFlag = 0x4_0000
    private static let shiftFlag = 0x2_0000

    private static let bindings = [
        Binding(
            id: "64", conflict: .spotlight,
            defaultShortcut: Shortcut(keyCode: spaceKeyCode, modifiers: .command)),
        Binding(
            id: "65", conflict: .finderSearch,
            defaultShortcut: Shortcut(keyCode: spaceKeyCode, modifiers: [.command, .option])),
    ]

    public static func conflict(for shortcut: Shortcut) -> HotKeyConflict? {
        let hotKeys = CFPreferencesCopyAppValue(
            "AppleSymbolicHotKeys" as CFString, "com.apple.symbolichotkeys" as CFString)
        return conflict(for: shortcut, symbolicHotKeys: hotKeys as? [String: Any] ?? [:])
    }

    static func conflict(
        for shortcut: Shortcut, symbolicHotKeys: [String: Any]
    ) -> HotKeyConflict? {
        bindings.first { binding in
            let entry = symbolicHotKeys[binding.id] as? [String: Any]
            guard entry?["enabled"] as? Bool ?? true else {
                return false
            }
            let parameters = (entry?["value"] as? [String: Any])?["parameters"] as? [Int] ?? []
            let current =
                if parameters.count > flagsIndex {
                    Shortcut(
                        keyCode: UInt32(truncatingIfNeeded: parameters[keyCodeIndex]),
                        modifiers: modifiers(parameters[flagsIndex]))
                } else {
                    binding.defaultShortcut
                }
            return current == shortcut
        }?.conflict
    }

    private static func modifiers(_ flags: Int) -> Shortcut.Modifiers {
        var result: Shortcut.Modifiers = []
        if flags & commandFlag != 0 { result.insert(.command) }
        if flags & optionFlag != 0 { result.insert(.option) }
        if flags & controlFlag != 0 { result.insert(.control) }
        if flags & shiftFlag != 0 { result.insert(.shift) }
        return result
    }
}
