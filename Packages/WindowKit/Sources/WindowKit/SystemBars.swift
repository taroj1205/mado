import AppKit
public import ApplicationServices

@AccessibilityActor
public enum SystemBars {
    private static let dockBundle = "com.apple.dock"
    nonisolated private static let statusLayer = Int(CGWindowLevelForKey(.statusWindow))

    nonisolated public static func statusItems(excluding window: CGWindowID?) -> [CGRect] {
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
        let entries = info as? [[String: Any]] ?? []
        return entries.compactMap { entry in
            guard entry[kCGWindowLayer as String] as? Int == statusLayer,
                entry[kCGWindowNumber as String] as? CGWindowID != window,
                let bounds = entry[kCGWindowBounds as String] as? [String: CGFloat]
            else { return nil }
            return CGRect(dictionaryRepresentation: bounds as CFDictionary)
        }
    }

    public static func dock() -> CGRect? {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: dockBundle)
        guard let pid = running.first?.processIdentifier else { return nil }
        let strip = children(of: application(pid)).first { element in
            (try? FocusedWindow.copy(kAXRoleAttribute, of: element)) as? String == kAXListRole
        }
        return strip.flatMap { frame(of: $0) }
    }

    public static func menus(of pid: pid_t) -> CGRect? {
        guard let value = try? FocusedWindow.copy(kAXMenuBarAttribute, of: application(pid)),
            let bar = try? FocusedWindow.element(value)
        else { return nil }
        return children(of: bar).compactMap { frame(of: $0) }.reduce(nil) { total, next in
            total.map { $0.union(next) } ?? next
        }
    }

    private static func application(_ pid: pid_t) -> AXUIElement {
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, FocusedWindow.messagingTimeout)
        return application
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        (try? FocusedWindow.copy(kAXChildrenAttribute, of: element)) as? [AXUIElement] ?? []
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        guard let position = try? FocusedWindow.copy(kAXPositionAttribute, of: element),
            let size = try? FocusedWindow.copy(kAXSizeAttribute, of: element)
        else { return nil }
        return FocusedWindow.frame(position: position, size: size)
    }
}
