import AppKit
import Foundation
import Testing

@testable import ClipboardKit

@Suite struct ClipboardStoreDuplicateTests {
    private static let png = Data([0x89, 0x50, 0x4E, 0x47])
    private static let roomy = ClipboardStore.Retention(period: nil, items: 100)

    private let directory = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)

    private static func text(_ text: String, at seconds: Double, from app: String? = nil) -> Clip {
        Clip(
            .text, text: text, type: nil, data: nil, source: app,
            date: Date(timeIntervalSince1970: seconds))
    }

    private static func image(at seconds: TimeInterval) -> Clip {
        Clip(
            .image, text: "", type: .png, data: png, source: nil,
            date: Date(timeIntervalSince1970: seconds))
    }

    private static func rich(
        _ text: String, _ type: NSPasteboard.PasteboardType, _ body: String, at seconds: Double
    ) -> Clip {
        Clip(
            .richText, text: text, type: type, data: Data(body.utf8), source: nil,
            date: Date(timeIntervalSince1970: seconds))
    }

    private func images() throws -> [String] {
        try FileManager.default.contentsOfDirectory(
            atPath: directory.appending(path: "Images").path)
    }

    @Test func movesARepeatedCopyToTheTopInsteadOfAddingIt() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)

        try await store.add(Self.text("a", at: 1, from: "com.apple.Notes"), keeping: Self.roomy)
        let first = try #require(try await store.search("", limit: 1).first)
        try await store.add(Self.text("b", at: 2), keeping: Self.roomy)
        try await store.add(Self.text("a", at: 3, from: "com.apple.Safari"), keeping: Self.roomy)
        let entries = try await store.search("", limit: 10)

        #expect(entries.map(\.text) == ["a", "b"])
        #expect(entries[0].id == first.id)
        #expect(entries[0].date == Date(timeIntervalSince1970: 3))
        #expect(entries[0].source == "com.apple.Safari")
    }

    @Test func keepsRichCopiesThatDifferInFormatting() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)
        let clips = [
            Self.rich("bold", .rtf, #"{\rtf1 \b bold}"#, at: 1),
            Self.rich("bold", .rtf, #"{\rtf1 \i bold}"#, at: 2),
            Self.rich("bold", .html, #"{\rtf1 \i bold}"#, at: 3),
        ]
        for clip in clips {
            try await store.add(clip, keeping: Self.roomy)
        }

        #expect(try await store.search("", limit: 10).count == clips.count)
    }

    @Test func givesAPlainCopyTheFormattingOfALaterRichCopyOfTheSameText() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)

        try await store.add(Self.text("319", at: 1), keeping: Self.roomy)
        try await store.add(Self.text("other", at: 2), keeping: Self.roomy)
        try await store.add(Self.rich("319", .html, "<b>319</b>", at: 3), keeping: Self.roomy)
        let entries = try await store.search("", limit: 10)

        #expect(entries.map(\.text) == ["319", "other"])
        #expect(entries[0].kind == .richText)
        #expect(entries[0].type == NSPasteboard.PasteboardType.html.rawValue)
        #expect(entries[0].date == Date(timeIntervalSince1970: 3))
        #expect(try await store.data(for: entries[0].id) == Data("<b>319</b>".utf8))

        try await store.add(Self.rich("319", .html, "<b>319</b>", at: 4), keeping: Self.roomy)
        #expect(try await store.search("", limit: 10).count == 2)
    }

    @Test func movesTheRichCopyToTheTopForALaterPlainCopyOfTheSameText() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)

        try await store.add(Self.rich("319", .html, "<b>319</b>", at: 1), keeping: Self.roomy)
        try await store.add(Self.text("other", at: 2), keeping: Self.roomy)
        try await store.add(
            Self.text("319", at: 3, from: "com.apple.Terminal"), keeping: Self.roomy)
        let entries = try await store.search("", limit: 10)

        #expect(entries.map(\.text) == ["319", "other"])
        #expect(entries[0].kind == .richText)
        #expect(entries[0].source == "com.apple.Terminal")
    }

    @Test func bringsAReusedEntryToTheTop() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)

        try await store.add(Self.text("a", at: 1), keeping: Self.roomy)
        let first = try #require(try await store.search("", limit: 1).first)
        try await store.add(Self.text("b", at: 2), keeping: Self.roomy)
        try await store.bringToTop(id: first.id, at: Date(timeIntervalSince1970: 3))

        #expect(try await store.search("", limit: 10).map(\.text) == ["a", "b"])
    }

    @Test func reusesTheSavedImageAndItsTextForARepeatedImage() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)

        try await store.add(Self.image(at: 1), keeping: Self.roomy)
        try await store.recognizeImages(onEach: nil) { _ in "found" }
        try await store.add(Self.text("between", at: 2), keeping: Self.roomy)
        try await store.add(Self.image(at: 3), keeping: Self.roomy)
        let entries = try await store.search("", limit: 10)

        #expect(entries.map(\.text) == ["found", "between"])
        #expect(entries[0].kind == .image)
        #expect(try images().count == 1)
    }

    @Test func keepsARepeatedPinnedCopyPinned() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)

        try await store.add(Self.text("a", at: 1), keeping: Self.roomy)
        let pinned = try #require(try await store.search("", limit: 1).first)
        try await store.setPinned(true, id: pinned.id)
        try await store.add(Self.text("b", at: 2), keeping: Self.roomy)
        try await store.add(Self.text("a", at: 3), keeping: Self.roomy)
        let entries = try await store.search("", limit: 10)

        #expect(entries.map(\.text) == ["a", "b"])
        #expect(entries.map(\.pinned) == [true, false])
    }

    @Test func mergesDuplicatesSavedBeforeThisVersion() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let folder = directory.appending(path: "Images")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for file in ["older.png", "newer.png"] {
            try Self.png.write(to: folder.appending(path: file))
        }
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
            ALTER TABLE clips ADD COLUMN recognized INTEGER NOT NULL DEFAULT 0;
            PRAGMA user_version = 3;
            INSERT INTO clips (kind, text, date) VALUES ('text', 'a', 1), ('text', 'b', 2),
                ('text', 'a', 3);
            INSERT INTO clips (kind, text, type, image, date, recognized)
                VALUES ('image', 'old text', 'public.png', 'older.png', 4, 1),
                    ('image', 'new text', 'public.png', 'newer.png', 5, 1);
            INSERT INTO clips (kind, text, date, pinned) VALUES ('text', 'c', 6, 1),
                ('text', 'c', 7, 0);
            """)

        let store = try ClipboardStore(directory: directory)
        try await store.mergeSavedDuplicates()
        let merged = try await store.search("", limit: 10)
        try await store.add(Self.text("a", at: 8), keeping: Self.roomy)
        try await store.add(Self.image(at: 9), keeping: Self.roomy)

        #expect(merged.map(\.text) == ["c", "new text", "a", "b"])
        #expect(merged.map(\.pinned) == [true, false, false, false])
        #expect(try images() == ["newer.png"])
        #expect(try await store.search("", limit: 10).map(\.text) == ["new text", "a", "c", "b"])
        #expect(try images() == ["newer.png"])
    }
}
