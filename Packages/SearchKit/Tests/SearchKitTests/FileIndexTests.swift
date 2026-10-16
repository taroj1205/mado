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

        let found = await FileIndex.files(in: [root])
        let files = found.filter { $0.path != root.path }.sorted { $0.name < $1.name }

        #expect(files.map(\.name) == ["Mado.app", "Planning", "Q3 Roadmap.pdf", "notes.md"])
        #expect(files[2].folder.hasSuffix("/\(root.lastPathComponent)/Planning"))
        #expect(files[2].key == Fuzzy.Key("Q3 Roadmap.pdf"))
        #expect(files[2].path == files[2].url.path)
    }

    @Test func findsTheSearchedFoldersThemselvesButNotMissingOnes() async throws {
        defer { try? FileManager.default.removeItem(at: root) }

        let found = await FileIndex.files(in: [root, root.appending(path: "Missing")])
        let top = try #require(found.first { $0.path == root.path })

        #expect(top.isFolder)
        #expect(top.name == root.lastPathComponent)
        #expect(top.key == Fuzzy.Key(root.lastPathComponent))
        #expect(!found.contains { $0.name == "Missing" })
    }

    @Test func skipsDependencyFoldersAndListsOverlappingFoldersOnce() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let dependency = root.appending(path: "node_modules/left-pad")
        try FileManager.default.createDirectory(
            at: dependency, withIntermediateDirectories: true)
        try Data().write(to: dependency.appending(path: "index.js"))

        let found = await FileIndex.files(in: [root, root.appending(path: "Planning")])

        #expect(!found.contains { $0.path.contains("node_modules") })
        #expect(Set(found.map(\.path)).count == found.count)
    }

    @Test func searchesTheNewFoldersAfterTheyAreChanged() async {
        defer { try? FileManager.default.removeItem(at: root) }
        let index = FileIndex(folders: [])
        index.start()
        await index.scan?.value
        #expect(index.files.isEmpty)

        index.use([root.appending(path: "Planning")])
        await index.scan?.value
        #expect(index.files.map(\.name).sorted() == ["Planning", "Q3 Roadmap.pdf"])

        index.use([])
        await index.scan?.value
        #expect(index.files.isEmpty)
    }

    @Test func ranksFilesWithTheUseAndAliasesSavedForTheirPath() async {
        defer { try? FileManager.default.removeItem(at: root) }
        let files = ["Report.pdf", "Recipe.pdf"].map { name in
            FileIndex.File(
                name: name, folder: "~", url: URL(filePath: "/tmp/\(name)"),
                path: "/tmp/\(name)", key: Fuzzy.Key(name), isFolder: false, modified: nil)
        }
        var usage = Usage()
        usage.record("/tmp/Recipe.pdf", at: .now)
        var items = ItemSettings()
        items["/tmp/Report.pdf"] = .init(aliases: ["taxes"])
        let rank = { (query: String) async in
            await FileIndex.rank(files, by: query, items: items, usage: usage, at: .now)
                .map(\.name)
        }

        #expect(await rank("re") == ["Recipe.pdf", "Report.pdf"])
        #expect(await rank("taxes") == ["Report.pdf"])
    }

    @Test func aQueryWithASlashMatchesTheFolderPathToo() async {
        defer { try? FileManager.default.removeItem(at: root) }
        let files = ["Planning", "Archive"].map { name in
            FileIndex.File(
                name: "Q3 Roadmap.pdf", folder: "~/Documents/\(name)",
                url: URL(filePath: "/Users/me/Documents/\(name)/Q3 Roadmap.pdf"),
                path: "/Users/me/Documents/\(name)/Q3 Roadmap.pdf",
                key: Fuzzy.Key("Q3 Roadmap.pdf"), isFolder: false, modified: nil)
        }
        let rank = { (query: String) async in
            await FileIndex.rank(files, by: query, items: ItemSettings(), usage: Usage(), at: .now)
                .map(\.folder)
        }

        #expect(await rank("q3").count == 2)
        #expect(await rank("planning/q3") == ["~/Documents/Planning"])
        #expect(await rank("docs/arch") == ["~/Documents/Archive"])
        #expect(await rank("/Users/me/Documents/Planning/q3") == ["~/Documents/Planning"])
    }

    @Test func aTrailingSlashFindsTheFolderAndWhatIsInsideIt() async {
        let make = { (name: String, folder: String) in
            let path = "/Users/me/\(folder.dropFirst(2))/\(name)"
            return FileIndex.File(
                name: name, folder: folder, url: URL(filePath: path), path: path,
                key: Fuzzy.Key(name), isFolder: true, modified: nil)
        }
        let files = [
            make("university", "~/coding"), make("compsci-220", "~/coding/university"),
            make("notes", "~/Documents"),
        ]

        let found = await FileIndex.rank(
            files, by: "coding/university/", items: ItemSettings(), usage: Usage(), at: .now)

        #expect(Set(found.map(\.name)) == ["university", "compsci-220"])
    }

    @Test func showsAnotherPageOfMatchesUntilThePageIsReset() {
        let index = FileIndex(folders: [])

        #expect(index.shown == FileIndex.page)
        index.showMore()
        #expect(index.shown == FileIndex.page * 2)
        index.resetPage()
        #expect(index.shown == FileIndex.page)
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
        #expect(index.files.count == 5)
        #expect(changes == 1)
        let notes = try #require(index.files.first { $0.name == "notes.md" }).url.path
        #expect(index.file(atPath: notes)?.name == "notes.md")

        try Data().write(to: root.appending(path: "draft.txt"))
        try FileManager.default.removeItem(at: root.appending(path: "notes.md"))

        let expected = [
            root.lastPathComponent, "Mado.app", "Planning", "Q3 Roadmap.pdf", "draft.txt",
        ].sorted()
        let deadline = ContinuousClock.now + .seconds(10)
        while index.files.map(\.name).sorted() != expected, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(index.files.map(\.name).sorted() == expected)
        #expect(changes == 2)
        #expect(index.file(atPath: notes) == nil)

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
