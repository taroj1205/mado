public import AppKit

@MainActor
public enum AppToggle {
    public static func app(for id: String) -> URL? {
        guard id.hasPrefix("/") else { return nil }
        let url = URL(filePath: id)
        return url.pathExtension == "app" ? url : nil
    }

    public static func toggle(_ app: URL) async throws {
        let workspace = NSWorkspace.shared
        let front = workspace.frontmostApplication
        if let front, let bundle = front.bundleURL, isSame(bundle, app) {
            front.hide()
        } else {
            _ = try await workspace.openApplication(
                at: app, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    static func isSame(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.resolvingSymlinksInPath().path == rhs.resolvingSymlinksInPath().path
    }
}
