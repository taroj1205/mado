import AppKit
import Testing

@testable import WindowKit

@MainActor
@Suite struct AppToggleTests {
    @Test func onlyAbsoluteAppPathsAreApps() {
        #expect(
            AppToggle.app(for: "/Applications/Safari.app")
                == URL(filePath: "/Applications/Safari.app"))
        #expect(AppToggle.app(for: "/Users/me/Notes.txt") == nil)
        #expect(AppToggle.app(for: "system.lock") == nil)
        #expect(AppToggle.app(for: "open.app") == nil)
    }

    @Test func matchesTheRunningBundleThroughSlashesAndSymlinks() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let app = root.appending(path: "Real.app")
        let link = root.appending(path: "Link.app")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: app)
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(AppToggle.isSame(URL(filePath: app.path + "/"), URL(filePath: app.path)))
        #expect(AppToggle.isSame(link, app))
        #expect(!AppToggle.isSame(root.appending(path: "Other.app"), app))
    }

    @Test func aPeekedAppHidesOnceAnotherAppComesForward() throws {
        let center = NotificationCenter()
        let peeked = NSRunningApplication.current
        let other = try #require(
            NSWorkspace.shared.runningApplications.first { $0 != peeked })
        var hidden = 0
        AppToggle.hide(peeked.processIdentifier, whenAnotherAppActivatesIn: center) {
            hidden += 1
        }
        AppToggle.hide(peeked.processIdentifier, whenAnotherAppActivatesIn: center) {
            hidden += 10
        }

        activate(peeked, in: center)
        #expect(hidden == 0)

        activate(other, in: center)
        activate(other, in: center)
        #expect(hidden == 1)
    }

    private func activate(_ app: NSRunningApplication, in center: NotificationCenter) {
        center.post(
            name: NSWorkspace.didActivateApplicationNotification, object: nil,
            userInfo: [NSWorkspace.applicationUserInfoKey: app])
    }
}
