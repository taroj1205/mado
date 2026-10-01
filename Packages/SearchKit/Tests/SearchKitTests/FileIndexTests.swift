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

    @Test func findsFilesAndFoldersButNotHiddenEntriesOrBundleContents() {
        defer { try? FileManager.default.removeItem(at: root) }

        let files = FileIndex.files(in: [root]).sorted { $0.name < $1.name }

        #expect(files.map(\.name) == ["Mado.app", "Planning", "Q3 Roadmap.pdf", "notes.md"])
        #expect(files[2].folder.hasSuffix("/\(root.lastPathComponent)/Planning"))
        #expect(files[2].key == Fuzzy.Key("Q3 Roadmap.pdf"))
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

    @Test func kindIsFolderOrWhenTheFileWasEdited() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Pacific/Auckland"))
        calendar.locale = Locale(identifier: "en_US")
        let now = try Date("2026-10-02T09:00:00+13:00", strategy: .iso8601)
        let today = calendar.startOfDay(for: now)
        let file = root.appending(path: "notes.md")

        func kind(daysAgo days: Int, hour: Int) throws -> String {
            let day = try #require(calendar.date(byAdding: .day, value: -days, to: today))
            let edited = try #require(calendar.date(byAdding: .hour, value: hour, to: day))
            try FileManager.default.setAttributes(
                [.modificationDate: edited], ofItemAtPath: file.path)
            return FileIndex.kind(of: file, at: now, in: calendar)
        }

        let folder = root.appending(path: "Planning")
        #expect(FileIndex.kind(of: folder, at: now, in: calendar) == "Folder")
        #expect(try kind(daysAgo: 0, hour: 0) == "Edited today")
        #expect(try kind(daysAgo: 1, hour: 23) == "Yesterday")
        #expect(try kind(daysAgo: 1, hour: 0) == "Yesterday")
        #expect(try kind(daysAgo: 4, hour: 12) == "Mon")
        #expect(try kind(daysAgo: 7, hour: 12) == "Sep 25, 2026")
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
    }
}
