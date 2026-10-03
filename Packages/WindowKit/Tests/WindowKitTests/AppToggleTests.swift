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

    @Test func aPeekedAppHidesOnceWhenItIsSwitchedAway() {
        let center = NotificationCenter()
        let app = NSRunningApplication.current
        var hides = 0
        AppToggle.hideWhenDeactivated(app.processIdentifier, in: center) { hides += 1 }

        deactivate(app, in: center)
        deactivate(app, in: center)

        #expect(hides == 1)
    }

    @Test func aPeekedAppThatQuitsStopsBeingWatched() {
        let center = NotificationCenter()
        let app = NSRunningApplication.current
        var hides = 0
        AppToggle.hideWhenDeactivated(app.processIdentifier, in: center) { hides += 1 }

        center.post(
            name: NSWorkspace.didTerminateApplicationNotification, object: nil,
            userInfo: [NSWorkspace.applicationUserInfoKey: app])
        deactivate(app, in: center)

        #expect(hides == 1)
    }

    @Test func otherAppsSwitchingAwayLeaveThePeekOpen() {
        let center = NotificationCenter()
        let app = NSRunningApplication.current
        var hides = 0
        AppToggle.hideWhenDeactivated(app.processIdentifier + 1, in: center) { hides += 1 }

        deactivate(app, in: center)
        center.post(name: NSWorkspace.didDeactivateApplicationNotification, object: nil)
        center.post(
            name: NSWorkspace.didActivateApplicationNotification, object: nil,
            userInfo: [NSWorkspace.applicationUserInfoKey: app])

        #expect(hides == 0)
    }

    @Test func peekingAgainReplacesTheEarlierWatch() {
        let center = NotificationCenter()
        let app = NSRunningApplication.current
        var first = 0
        var second = 0
        AppToggle.hideWhenDeactivated(app.processIdentifier, in: center) { first += 1 }
        AppToggle.hideWhenDeactivated(app.processIdentifier, in: center) { second += 1 }

        deactivate(app, in: center)

        #expect(first == 0)
        #expect(second == 1)
    }

    private func deactivate(_ app: NSRunningApplication, in center: NotificationCenter) {
        center.post(
            name: NSWorkspace.didDeactivateApplicationNotification, object: nil,
            userInfo: [NSWorkspace.applicationUserInfoKey: app])
    }
}
