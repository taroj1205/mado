import Foundation
import Testing

@testable import AppCore

@Suite struct SettingsStoreTests {
    struct LauncherSettings: Codable, Equatable {
        var hotkey: String
        var maxResults: Int
    }

    func makeStore() -> SettingsStore {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        return SettingsStore(url: dir.appending(path: "settings.json"))
    }

    @Test func missingFileLoadsEmptySettings() throws {
        #expect(try makeStore().load() == Settings())
    }

    @Test func savedSettingsRoundTrip() throws {
        let store = makeStore()
        var settings = Settings()
        let launcher = LauncherSettings(hotkey: "cmd+space", maxResults: 8)
        try settings.setValue(launcher, for: "launcher")
        try store.save(settings)

        let loaded = try store.load()
        #expect(loaded == settings)
        #expect(try loaded.value(LauncherSettings.self, for: "launcher") == launcher)
        #expect(try loaded.value(LauncherSettings.self, for: "clipboard") == nil)
    }

    @Test func version0FileMigratesToVersion1() throws {
        let store = makeStore()
        try FileManager.default.createDirectory(
            at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"launcher":{"hotkey":"cmd+space","maxResults":8}}"#.utf8).write(to: store.url)

        let loaded = try store.load()
        #expect(
            try loaded.value(LauncherSettings.self, for: "launcher")
                == LauncherSettings(hotkey: "cmd+space", maxResults: 8))

        try store.save(loaded)
        let rewritten = try String(contentsOf: store.url, encoding: .utf8)
        #expect(rewritten.contains(#""version" : 1"#))
    }

    @Test func newerVersionIsRejected() throws {
        let store = makeStore()
        try FileManager.default.createDirectory(
            at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"version":99,"modules":{}}"#.utf8).write(to: store.url)

        #expect(throws: SettingsError.unsupportedVersion(99)) { try store.load() }
    }

    @Test func garbageFileIsReportedAsCorrupt() throws {
        let store = makeStore()
        try FileManager.default.createDirectory(
            at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.url)

        #expect(throws: SettingsError.corrupt) { try store.load() }
    }

    @Test func repeatedSavesLeaveOnlyTheSettingsFile() throws {
        let store = makeStore()
        for count in 1...5 {
            var settings = Settings()
            try settings.setValue(count, for: "counter")
            try store.save(settings)
        }
        let files = try FileManager.default.contentsOfDirectory(
            atPath: store.url.deletingLastPathComponent().path(percentEncoded: false))
        #expect(files == ["settings.json"])
        #expect(try store.load().value(Int.self, for: "counter") == 5)
    }
}
