public import AppKit

@MainActor
public enum AppToggle {
    private static var peeks: [pid_t: any NSObjectProtocol] = [:]

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
        let pid = opened.processIdentifier
        hide(pid, whenAnotherAppActivatesIn: NSWorkspace.shared.notificationCenter) {
            opened.hide()
        }
    }

    static func hide(
        _ pid: pid_t, whenAnotherAppActivatesIn center: NotificationCenter,
        hide: @escaping @MainActor () -> Void
    ) {
        guard peeks[pid] == nil else { return }
        peeks[pid] = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { note in
            let active = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard active?.processIdentifier != pid else { return }
            MainActor.assumeIsolated {
                if let token = peeks.removeValue(forKey: pid) {
                    center.removeObserver(token)
                    hide()
                }
            }
        }
    }

    static func isSame(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.resolvingSymlinksInPath().path == rhs.resolvingSymlinksInPath().path
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
