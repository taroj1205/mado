import AppCore
import AppKit
import WindowKit

enum LauncherScreen {
    case activeWindow
    case display(id: String, name: String)
    case mouse

    private static let field = "screen"

    var id: String {
        switch self {
        case .activeWindow: "active_window"
        case .display(let id, _): id
        case .mouse: "mouse"
        }
    }

    var title: String {
        switch self {
        case .activeWindow: "Screen with Active Window"
        case .display(_, let name) where isAvailable: name
        case .display(_, let name): "\(name) (Not Connected)"
        case .mouse: "Screen with Mouse"
        }
    }

    var isAvailable: Bool {
        guard case .display = self else { return true }
        return connectedScreen != nil
    }

    var screen: NSScreen? {
        let mouse = NSEvent.mouseLocation
        let mouseScreen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
        switch self {
        case .activeWindow:
            return Self.activeWindowScreen() ?? mouseScreen

        case .display:
            return connectedScreen ?? mouseScreen

        case .mouse:
            return mouseScreen
        }
    }

    private var connectedScreen: NSScreen? {
        NSScreen.screens.first { Self.uuid(of: $0) == id }
    }

    static func displays(keeping saved: Self) -> [Self] {
        let connected = NSScreen.screens.compactMap { screen in
            uuid(of: screen).map { Self.display(id: $0, name: screen.localizedName) }
        }
        guard case .display = saved, !connected.contains(where: { $0.id == saved.id }) else {
            return connected
        }
        return connected + [saved]
    }

    @MainActor
    static func load(from modules: ModuleManager?) -> Self {
        switch LauncherSettings.value(field, in: modules) {
        case .string(Self.activeWindow.id):
            return .activeWindow

        case .object(let display):
            guard case .string(let id) = display["id"], case .string(let name) = display["name"]
            else { return .mouse }
            return .display(id: id, name: name)

        default:
            return .mouse
        }
    }

    private static func uuid(of screen: NSScreen) -> String? {
        guard
            let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                as? CGDirectDisplayID,
            let uuid = unsafe CGDisplayCreateUUIDFromDisplayID(number)?.takeRetainedValue()
        else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
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

    @MainActor
    func save(to modules: ModuleManager?) throws {
        let value: JSONValue =
            switch self {
            case let .display(id, name): .object(["id": .string(id), "name": .string(name)])
            case .activeWindow, .mouse: .string(id)
            }
        try LauncherSettings.setValue(value, for: Self.field, in: modules)
    }
}
