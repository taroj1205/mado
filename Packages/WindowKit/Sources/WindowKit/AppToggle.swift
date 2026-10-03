public import AppKit

@MainActor
public enum AppToggle {
    private static let leaves = [
        NSWorkspace.didDeactivateApplicationNotification,
        NSWorkspace.didTerminateApplicationNotification,
    ]
    private static var peeks: [pid_t: [any NSObjectProtocol]] = [:]

    public static func app(for id: String) -> URL? {
        guard id.hasPrefix("/") else { return nil }
        let url = URL(filePath: id)
        return url.pathExtension == "app" ? url : nil
    }

    public static func toggle(_ app: URL) async throws {
        _ = try await bringForward(app)
    }

    public static func peek(_ app: URL) async throws {
        guard let opened = try await bringForward(app) else { return }
        hideWhenDeactivated(opened.processIdentifier, in: NSWorkspace.shared.notificationCenter) {
            opened.hide()
        }
    }

    static func hideWhenDeactivated(
        _ pid: pid_t, in center: NotificationCenter, hide: @escaping @MainActor () -> Void
    ) {
        stopWatching(pid, in: center)
        let watch: @Sendable (Notification) -> Void = { [weak center] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
            guard (app as? NSRunningApplication)?.processIdentifier == pid else { return }
            MainActor.assumeIsolated {
                if let center {
                    stopWatching(pid, in: center)
                }
                hide()
            }
        }
        peeks[pid] = leaves.map { name in
            center.addObserver(forName: name, object: nil, queue: .main, using: watch)
        }
    }

    static func isSame(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.resolvingSymlinksInPath().path == rhs.resolvingSymlinksInPath().path
    }

    private static func stopWatching(_ pid: pid_t, in center: NotificationCenter) {
        for observer in peeks.removeValue(forKey: pid) ?? [] {
            center.removeObserver(observer)
        }
    }

    private static func bringForward(_ app: URL) async throws -> NSRunningApplication? {
        let workspace = NSWorkspace.shared
        let front = workspace.frontmostApplication
        if let front, let bundle = front.bundleURL, isSame(bundle, app) {
            front.hide()
            return nil
        }
        return try await workspace.openApplication(
            at: app, configuration: NSWorkspace.OpenConfiguration())
    }
}
