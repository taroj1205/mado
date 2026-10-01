import Foundation
import Testing

@testable import SearchKit

@MainActor
@Suite struct FileIndexTests {
    private let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        for path in ["Planning", "Mado.app/Contents", ".git"] {
            try FileManager.default.createDirectory(
                at: root.appending(path: path), withIntermediateDirectories: true)
        }
        for path in ["Planning/Q3 Roadmap.pdf", "notes.md", ".DS_Store", ".git/HEAD"] {
            try Data().write(to: root.appending(path: path))
        }
    }

    @Test func findsFilesAndFoldersButNotHiddenEntriesOrBundleContents() async {
        defer { try? FileManager.default.removeItem(at: root) }

        let files = await FileIndex.files(in: [root]).sorted { $0.name < $1.name }

        #expect(files.map(\.name) == ["Mado.app", "Planning", "Q3 Roadmap.pdf", "notes.md"])
        #expect(files[2].folder.hasSuffix("/\(root.lastPathComponent)/Planning"))
        #expect(files[2].key == Fuzzy.Key("Q3 Roadmap.pdf"))
    }

    @Test func aCancelledScanStopsWalkingTheFolders() async {
        defer { try? FileManager.default.removeItem(at: root) }
        let scan = Task { await FileIndex.files(in: [root]) }
        scan.cancel()
        #expect(await scan.value.isEmpty)
    }

    @Test func foldersInsideHomeStartWithATilde() {
        defer { try? FileManager.default.removeItem(at: root) }
        let home = URL.homeDirectory
        #expect(
            FileIndex.abbreviated(home.appending(path: "Documents/Planning"))
                == "~/Documents/Planning")
        #expect(FileIndex.abbreviated(home) == "~")
        #expect(FileIndex.abbreviated(URL(filePath: home.path + "2")) == home.path + "2")
        #expect(FileIndex.abbreviated(URL(filePath: "/tmp/Planning")) == "/tmp/Planning")
    }

    @Test func kindIsFolderOrWhenTheFileWasEdited() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Pacific/Auckland"))
        calendar.locale = Locale(identifier: "en_US")
        let now = try Date("2026-10-02T09:00:00+13:00", strategy: .iso8601)
        let today = calendar.startOfDay(for: now)
        let path = root.appending(path: "notes.md").path

        func kind(of name: String) async throws -> String {
            let file = try #require(await FileIndex.files(in: [root]).first { $0.name == name })
            return FileIndex.kind(of: file, at: now, in: calendar)
        }

        func kind(daysAgo days: Int, hour: Int) async throws -> String {
            let day = try #require(calendar.date(byAdding: .day, value: -days, to: today))
            let edited = try #require(calendar.date(byAdding: .hour, value: hour, to: day))
            try FileManager.default.setAttributes([.modificationDate: edited], ofItemAtPath: path)
            return try await kind(of: "notes.md")
        }

        #expect(try await kind(of: "Planning") == "Folder")
        #expect(try await kind(of: "Mado.app") != "Folder")
        #expect(try await kind(daysAgo: 0, hour: 0) == "Edited today")
        #expect(try await kind(daysAgo: 1, hour: 23) == "Yesterday")
        #expect(try await kind(daysAgo: 1, hour: 0) == "Yesterday")
        #expect(try await kind(daysAgo: 4, hour: 12) == "Mon")
        #expect(try await kind(daysAgo: 7, hour: 12) == "Sep 25, 2026")
    }

    @Test func followsFilesAddedAndRemoved() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let index = FileIndex(folders: [root, root.appending(path: "Missing")])
        var changes = 0
        index.onChange = { changes += 1 }
        index.start()
        await index.scan?.value
        #expect(index.files.count == 4)
        #expect(changes == 1)

        try Data().write(to: root.appending(path: "draft.txt"))
        try FileManager.default.removeItem(at: root.appending(path: "notes.md"))

        let expected = ["Mado.app", "Planning", "Q3 Roadmap.pdf", "draft.txt"]
        let deadline = ContinuousClock.now + .seconds(10)
        while index.files.map(\.name).sorted() != expected, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(index.files.map(\.name).sorted() == expected)
        #expect(changes == 2)

        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -3_600)],
            ofItemAtPath: root.appending(path: "draft.txt").path)
        let edited = ContinuousClock.now + .seconds(10)
        while changes < 3, ContinuousClock.now < edited {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(changes == 3)
    }
}
