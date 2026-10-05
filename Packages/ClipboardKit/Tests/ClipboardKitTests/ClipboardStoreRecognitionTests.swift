import AppKit
import Foundation
import Testing

@testable import ClipboardKit

@Suite struct ClipboardStoreRecognitionTests {
    private actor Reads {
        private(set) var files: [String] = []
        private(set) var mostAtOnce = 0
        private var reading = 0

        func start(_ file: URL) {
            files.append(file.lastPathComponent)
            reading += 1
            mostAtOnce = max(mostAtOnce, reading)
        }

        func finish() {
            reading -= 1
        }
    }

    private struct Failure: Error {}

    private static let png = Data([0x89, 0x50, 0x4E, 0x47])
    private static let roomy = ClipboardStore.Retention(items: 100)

    private let directory = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)

    private static func image(at seconds: TimeInterval) -> Clip {
        Clip(
            .image, text: "", type: .png, data: png + Data("\(seconds)".utf8), source: nil,
            date: Date(timeIntervalSince1970: seconds))
    }

    private static func text(_ text: String, at seconds: TimeInterval) -> Clip {
        Clip(
            .text, text: text, type: nil, data: nil, source: nil,
            date: Date(timeIntervalSince1970: seconds))
    }

    @Test func readsImagesSavedBeforeRecognitionNewestFirst() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(
            at: directory.appending(path: "Images"), withIntermediateDirectories: true)
        try Database(
            path: directory.appending(path: ClipboardStore.fileName).path(percentEncoded: false)
        ).execute(
            """
            CREATE TABLE clips (
                id INTEGER PRIMARY KEY, kind TEXT NOT NULL, text TEXT NOT NULL, type TEXT,
                data BLOB, image TEXT, source TEXT, date REAL NOT NULL
            );
            CREATE INDEX clips_by_date ON clips (date);
            ALTER TABLE clips ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0;
            PRAGMA user_version = 2;
            INSERT INTO clips (kind, text, image, date) VALUES ('image', '', 'old.png', 1);
            INSERT INTO clips (kind, text, date) VALUES ('text', 'copied text', 2);
            INSERT INTO clips (kind, text, image, date, pinned)
            VALUES ('image', '', 'pinned.png', 3, 1);
            """)
        let reads = Reads()

        let store = try ClipboardStore(directory: directory)
        try await store.recognizeImages(onEach: nil) { file in
            await reads.start(file)
            await reads.finish()
            return "text in \(file.lastPathComponent)"
        }

        #expect(await reads.files == ["pinned.png", "old.png"])
        #expect(
            try await store.search("", limit: 10).map(\.text) == [
                "text in pinned.png", "copied text", "text in old.png",
            ])
        #expect(try await store.search("pinned", limit: 10).map(\.pinned) == [true])
    }

    @Test func reportsEachImageAsSoonAsItsTextIsSaved() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)
        for index in 0..<2 {
            try await store.add(Self.image(at: Double(index)), keeping: Self.roomy)
        }
        let reads = Reads()

        try await store.recognizeImages {
            let found = try? await store.search("QX7K2M", limit: 10).count
            await reads.start(URL(filePath: "saved \(found ?? -1)"))
            await reads.finish()
        } using: { file in
            await reads.start(file)
            await reads.finish()
            return "QX7K2M"
        }

        let files = await reads.files
        #expect(files.map { $0.hasPrefix("saved") } == [false, true, false, true])
        #expect(files.filter { $0.hasPrefix("saved") } == ["saved 1", "saved 2"])
    }

    @Test func readsOneImageAtATimeAndEachOnce() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)
        for index in 0..<3 {
            try await store.add(Self.image(at: Double(index)), keeping: Self.roomy)
        }
        let reads = Reads()
        let read: @Sendable (URL) async throws -> String = { file in
            await reads.start(file)
            try await Task.sleep(for: .milliseconds(20))
            await reads.finish()
            return "found"
        }

        async let first: Void = store.recognizeImages(onEach: nil, using: read)
        async let second: Void = store.recognizeImages(onEach: nil, using: read)
        _ = try await (first, second)

        #expect(await reads.mostAtOnce == 1)
        #expect(await Set(reads.files).count == 3)
        #expect(await reads.files.count == 3)
        #expect(try await store.search("found", limit: 10).count == 3)
    }

    @Test func movesOnWhenAnImageCannotBeRead() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)
        try await store.add(Self.image(at: 0), keeping: Self.roomy)
        try await store.add(Self.image(at: 1), keeping: Self.roomy)
        let reads = Reads()
        let read: @Sendable (URL) async throws -> String = { file in
            await reads.start(file)
            await reads.finish()
            if await reads.files.count == 1 {
                throw Failure()
            }
            return "readable"
        }

        try await store.recognizeImages(onEach: nil, using: read)
        try await store.recognizeImages(onEach: nil, using: read)

        #expect(await reads.files.count == 2)
        #expect(try await store.search("", limit: 10).map(\.text) == ["", "readable"])
    }

    @Test func dropsTextReadFromAnImageClearedMeanwhile() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)
        try await store.add(Self.image(at: 0), keeping: Self.roomy)
        let image = try #require(try await store.search("", limit: 1).first)

        try await store.recognizeImages(onEach: nil) { _ in
            try await store.clear()
            try await store.add(Self.text("copied later", at: 1), keeping: Self.roomy)
            return "cleared image text"
        }
        let entries = try await store.search("", limit: 10)

        #expect(entries.map(\.id) == [image.id])
        #expect(entries.map(\.text) == ["copied later"])
        #expect(try await store.search("cleared", limit: 10).isEmpty)
    }

    @Test func leavesTheRestForTheNextLaunchWhenCancelled() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)
        try await store.add(Self.image(at: 0), keeping: Self.roomy)
        try await store.add(Self.image(at: 1), keeping: Self.roomy)
        let (started, starting) = AsyncStream.makeStream(of: Void.self)
        let run = Task {
            try await store.recognizeImages(onEach: nil) { _ in
                starting.yield()
                try? await Task.sleep(for: .seconds(60))
                return "before quitting"
            }
        }

        for await _ in started {
            break
        }
        run.cancel()
        try await run.value
        let reads = Reads()
        try await ClipboardStore(directory: directory).recognizeImages(onEach: nil) { file in
            await reads.start(file)
            await reads.finish()
            return "after relaunch"
        }

        #expect(await reads.files.count == 1)
        #expect(
            try await store.search("", limit: 10).map(\.text) == [
                "before quitting", "after relaunch",
            ])
    }

    @Test func finishesTheRestAfterACancelledRunStops() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)
        try await store.add(Self.image(at: 0), keeping: Self.roomy)
        try await store.add(Self.image(at: 1), keeping: Self.roomy)
        let (started, starting) = AsyncStream.makeStream(of: Void.self)
        let stopped = Task {
            try await store.recognizeImages(onEach: nil) { _ in
                starting.yield()
                try? await Task.sleep(for: .seconds(60))
                return "stopped"
            }
        }
        for await _ in started {
            break
        }

        let restarted = Task { try await store.recognizeImages(onEach: nil) { _ in "restarted" } }
        stopped.cancel()
        try await stopped.value
        try await restarted.value

        #expect(try await store.search("", limit: 10).map(\.text) == ["stopped", "restarted"])
    }
}
