public import AppCore
import AppKit
import Carbon.HIToolbox
import CoreGraphics

public struct EnterGuard {
    enum Action: Equatable {
        case pass
        case newLine
        case send
    }

    private static let returnKeys = [kVK_Return, kVK_ANSI_KeypadEnter].map(Int64.init)
    private static let nonTextKeys = Set(
        [
            kVK_Tab, kVK_Space, kVK_Delete, kVK_ForwardDelete, kVK_Escape, kVK_LeftArrow,
            kVK_RightArrow, kVK_UpArrow, kVK_DownArrow, kVK_Home, kVK_End, kVK_PageUp,
            kVK_PageDown, kVK_Help, kVK_ANSI_KeypadClear, kVK_JIS_Eisu, kVK_JIS_Kana,
            kVK_VolumeUp, kVK_VolumeDown, kVK_Mute, kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5,
            kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12, kVK_F13, kVK_F14,
            kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
        ].map(Int64.init))
    private static let modifiers: CGEventFlags = [
        .maskShift, .maskControl, .maskAlternate, .maskCommand,
    ]
    private static let shortcutModifiers: CGEventFlags = [.maskControl, .maskCommand]

    private(set) var composingIn: pid_t?

    @MainActor
    public static func install(
        name: String, context: ModuleContext, settings: EnterGuardSettings
    ) throws(ModuleError) {
        var keys = Self()
        try context.tapEvents(name, matching: [.keyDown]) { _, event in
            let target = pid_t(
                truncatingIfNeeded: event.getIntegerValueField(.eventTargetUnixProcessID))
            let action = keys.handle(
                keyCode: event.getIntegerValueField(.keyboardEventKeycode), flags: event.flags,
                target: target, composes: { !InputSource.currentTypesASCII },
                isGuarded: {
                    settings.guards(
                        NSRunningApplication(processIdentifier: target)?.bundleIdentifier)
                })
            switch action {
            case .pass: break
            case .newLine: event.flags.insert(.maskShift)
            case .send: event.flags.remove(.maskCommand)
            }
            return false
        }
        context.observe(
            NSWorkspace.didActivateApplicationNotification,
            on: NSWorkspace.shared.notificationCenter,
            reading: { notification in
                let key = NSWorkspace.applicationUserInfoKey
                return (notification.userInfo?[key] as? NSRunningApplication)?.processIdentifier
            },
            handler: { app in keys.activated(app) })
    }

    mutating func handle(
        keyCode: Int64, flags: CGEventFlags, target: pid_t, composes: () -> Bool,
        isGuarded: () -> Bool
    ) -> Action {
        let held = flags.intersection(Self.modifiers)
        guard Self.returnKeys.contains(keyCode) else {
            let typesText = !Self.nonTextKeys.contains(keyCode)
            let isShortcut = !held.isDisjoint(with: Self.shortcutModifiers)
            if composingIn != target, typesText, !isShortcut, composes() {
                composingIn = target
            }
            return .pass
        }
        guard composingIn != target else {
            composingIn = nil
            return .pass
        }
        guard isGuarded() else { return .pass }
        switch held {
        case []: return .newLine
        case .maskCommand: return .send
        default: return .pass
        }
    }

    mutating func activated(_ app: pid_t?) {
        if composingIn != app {
            composingIn = nil
        }
    }
}
