import Foundation
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
}
