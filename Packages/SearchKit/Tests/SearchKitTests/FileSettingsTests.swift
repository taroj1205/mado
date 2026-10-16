import Foundation
import Testing

@testable import SearchKit

@Suite struct FileSettingsTests {
    private let defaults = FileIndex.folders.map(\.path)

    @Test func searchesTheDefaultFoldersUntilOneIsAddedOrRemoved() {
        var settings = FileSettings()
        #expect(settings.folders.map(\.path) == defaults)

        settings.add("/Users/me/coding")
        settings.add("/Users/me/coding")
        #expect(settings.paths == defaults + ["/Users/me/coding"])

        settings.remove(defaults[0])
        #expect(settings.paths == Array(defaults.dropFirst()) + ["/Users/me/coding"])

        settings.add(defaults[0])
        #expect(settings.paths == defaults + ["/Users/me/coding"])
    }

    @Test func removingEveryFolderLeavesNoneInsteadOfTheDefaults() {
        var settings = FileSettings()
        settings.add("/Users/me/coding")
        settings.paths.forEach { settings.remove($0) }

        #expect(settings.folders.isEmpty)
    }

    @Test func theChosenFoldersSurviveSavingAndLoading() throws {
        var settings = FileSettings()
        settings.add("/Users/me/coding")
        settings.remove(defaults[0])

        let decoder = JSONDecoder()
        let loaded = try decoder.decode(FileSettings.self, from: JSONEncoder().encode(settings))

        #expect(loaded == settings)
        #expect(try decoder.decode(FileSettings.self, from: Data("{}".utf8)) == FileSettings())
    }
}
