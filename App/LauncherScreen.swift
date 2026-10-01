import AppKit
import WindowKit

enum LauncherScreen: String, LauncherSetting {
    case activeWindow = "active_window"
    case mouse = "mouse"

    static let field = "screen"
    static let fallback = Self.mouse

    var title: String {
        switch self {
        case .activeWindow: "Screen with Active Window"
        case .mouse: "Screen with Mouse"
        }
    }

    var screen: NSScreen? {
        let mouse = NSEvent.mouseLocation
        let mouseScreen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
        switch self {
        case .mouse:
            return mouseScreen

        case .activeWindow:
            return Self.activeWindowScreen() ?? mouseScreen
        }
    }

    private static func activeWindowScreen() -> NSScreen? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
            let windows = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]],
            let window = windows.first(where: { info in
                info[kCGWindowOwnerPID as String] as? pid_t == pid
                    && info[kCGWindowLayer as String] as? Int == 0
            }),
            let dictionary = window[kCGWindowBounds as String] as? [String: Any],
            let bounds = CGRect(dictionaryRepresentation: dictionary as CFDictionary)
        else { return nil }
        let screens = NSScreen.screens
        return ScreenGeometry.screenIndex(showing: bounds, in: screens.map(\.frame))
            .map { screens[$0] }
    }
}
