import Foundation
import Testing

@testable import SearchKit

@MainActor
@Suite struct AppIndexTests {
    private let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        for path in [
            "Beta.app/Contents/Helper.app", "Utilities/Alpha.app", ".Hidden.app", ".Dot/Dot.app",
            "Flagged.app",
        ] {
            try FileManager.default.createDirectory(
                at: root.appending(path: path), withIntermediateDirectories: true)
        }
        try Data().write(to: root.appending(path: "notes.txt"))
        var flagged = root.appending(path: "Flagged.app")
        var values = URLResourceValues()
        values.isHidden = true
        try flagged.setResourceValues(values)
    }

    @Test func findsAppsButNotDotEntriesOrBundleContents() {
        defer { try? FileManager.default.removeItem(at: root) }

        let apps = AppIndex.apps(in: [root])

        #expect(apps.map(\.name) == ["Alpha", "Beta", "Flagged"])
        #expect(apps.map(\.folder) == ["Utilities", "", ""])
    }

    @Test func followsAppsAddedAndRemovedWithinTenSeconds() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let index = AppIndex(folders: [root, root.appending(path: "Missing")])
        index.start()
        await index.scan?.value
        #expect(index.apps.map(\.name) == ["Alpha", "Beta", "Flagged"])
        let beta = try #require(index.apps.first { $0.name == "Beta" }).url.path
        #expect(index.app(atPath: beta)?.name == "Beta")

        try FileManager.default.createDirectory(
            at: root.appending(path: "Gamma.app"), withIntermediateDirectories: false)
        try FileManager.default.removeItem(at: root.appending(path: "Beta.app"))

        let expected = ["Alpha", "Flagged", "Gamma"]
        let deadline = ContinuousClock.now + .seconds(10)
        while index.apps.map(\.name) != expected, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(index.apps.map(\.name) == expected)
        #expect(index.app(atPath: beta) == nil)
    }
}
