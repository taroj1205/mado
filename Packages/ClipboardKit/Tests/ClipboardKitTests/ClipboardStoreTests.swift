import AppKit
import Foundation
import Testing

@testable import ClipboardKit

@Suite struct ClipboardStoreTests {
    private static let day: TimeInterval = 86_400
    private static let roomy = ClipboardStore.Retention(items: 100)

    private let directory = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)

    private static func text(_ text: String, at seconds: TimeInterval) -> Clip {
        Clip(
            .text, text: text, type: nil, data: nil, source: nil,
            date: Date(timeIntervalSince1970: seconds))
    }

    private func images() throws -> [String] {
        try FileManager.default.contentsOfDirectory(
            atPath: directory.appending(path: "Images").path)
    }

    @Test func keepsEachKindWithItsMetadata() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)
        let rtf = Data(#"{\rtf1 bold}"#.utf8)
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        let date = Date(timeIntervalSince1970: 1_000)

        try await store.add(
            Clip(
                .richText, text: "bold", type: .rtf, data: rtf, source: "com.apple.TextEdit",
                date: date),
            keeping: Self.roomy)
        try await store.add(
            Clip(.image, text: "", type: .png, data: png, source: nil, date: date + 1),
            keeping: Self.roomy)
        let entries = try await store.search("", limit: 10)

        #expect(entries.map(\.kind) == [.image, .richText])
        #expect(entries[1].text == "bold")
        #expect(entries[1].data == rtf)
        #expect(entries[1].type == NSPasteboard.PasteboardType.rtf.rawValue)
        #expect(entries[1].source == "com.apple.TextEdit")
        #expect(entries[1].date == date)
        #expect(entries[0].data == nil)
        let image = try #require(entries[0].image)
        #expect(image.pathExtension == "png")
        #expect(try Data(contentsOf: image) == png)
    }

    @Test func dropsTheOldestOnceOverTheItemLimit() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)
        let limit = ClipboardStore.Retention(items: 3)
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        let now = Date()

        try await store.add(
            Clip(.image, text: "", type: .png, data: png, source: nil, date: now),
            keeping: limit)
        for index in 1...4 {
            try await store.add(
                Self.text("item \(index)", at: now.timeIntervalSince1970 + Double(index)),
                keeping: limit)
        }

        #expect(
            try await store.search("", limit: 10).map(\.text) == ["item 4", "item 3", "item 2"])
        #expect(try images().isEmpty)
    }

    @Test func dropsItemsOlderThanTheKeepingPeriod() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)
        let now = Date().timeIntervalSince1970

        try await store.add(Self.text("old", at: now - 31 * Self.day), keeping: Self.roomy)
        try await store.add(Self.text("recent", at: now - 29 * Self.day), keeping: Self.roomy)
        try await store.add(Self.text("new", at: now), keeping: Self.roomy)

        #expect(try await store.search("", limit: 10).map(\.text) == ["new", "recent"])
    }

    @Test func keepsPinnedItemsPastTheKeepingPeriod() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)
        let now = Date().timeIntervalSince1970
        let png = Data([0x89, 0x50, 0x4E, 0x47])

        try await store.add(
            Clip(
                .image, text: "", type: .png, data: png, source: nil,
                date: Date(timeIntervalSince1970: now - 2)),
            keeping: Self.roomy)
        try await store.add(Self.text("pinned", at: now - 1), keeping: Self.roomy)
        try await store.add(Self.text("unpinned", at: now), keeping: Self.roomy)
        for entry in try await store.search("", limit: 10) where entry.text != "unpinned" {
            try await store.setPinned(true, id: entry.id)
        }
        try await store.prune(
            keeping: Self.roomy, now: Date(timeIntervalSince1970: now + 31 * Self.day))
        let kept = try await store.search("", limit: 10)

        #expect(kept.map(\.text) == ["pinned", ""])
        #expect(kept.map(\.pinned) == [true, true])
        #expect(try images().count == 1)

        try await store.setPinned(false, id: kept[0].id)
        try await store.prune(
            keeping: Self.roomy, now: Date(timeIntervalSince1970: now + 31 * Self.day))

        #expect(try await store.search("", limit: 10).map(\.text) == [""])
    }

    @Test func leavesPinnedItemsOutOfTheItemLimit() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)
        let limit = ClipboardStore.Retention(items: 2)
        let now = Date().timeIntervalSince1970

        try await store.add(Self.text("pinned", at: now), keeping: limit)
        let pinned = try #require(try await store.search("", limit: 1).first)
        try await store.setPinned(true, id: pinned.id)
        for index in 1...3 {
            try await store.add(Self.text("item \(index)", at: now + Double(index)), keeping: limit)
        }

        #expect(
            try await store.search("", limit: 10).map(\.text) == ["item 3", "item 2", "pinned"])
    }

    @Test func opensAHistorySavedBeforePinning() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Database(
            path: directory.appending(path: ClipboardStore.fileName).path(percentEncoded: false)
        ).execute(
            """
            CREATE TABLE clips (
                id INTEGER PRIMARY KEY, kind TEXT NOT NULL, text TEXT NOT NULL, type TEXT,
                data BLOB, image TEXT, source TEXT, date REAL NOT NULL
            );
            CREATE INDEX clips_by_date ON clips (date);
            INSERT INTO clips (kind, text, date) VALUES ('text', 'saved earlier', 1);
            """)

        let store = try ClipboardStore(directory: directory)
        let saved = try #require(try await store.search("", limit: 10).first)
        try await store.setPinned(true, id: saved.id)
        let reopened = try ClipboardStore(directory: directory)

        #expect(saved.text == "saved earlier")
        #expect(!saved.pinned)
        #expect(try await reopened.search("", limit: 10).map(\.pinned) == [true])
    }

    @Test func clearsEverythingButPinnedItems() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        for (index, text) in ["pinned", "copied", "kept image", "image"].enumerated() {
            let date = Date(timeIntervalSince1970: Double(index))
            try await store.add(
                text.hasSuffix("image")
                    ? Clip(.image, text: text, type: .png, data: png, source: nil, date: date)
                    : Self.text(text, at: Double(index)),
                keeping: Self.roomy)
        }
        for entry in try await store.search("", limit: 10) where entry.text.hasPrefix("k") {
            try await store.setPinned(true, id: entry.id)
        }
        let pinned = try #require(try await store.search("pinned", limit: 1).first)
        try await store.setPinned(true, id: pinned.id)
        try Data().write(to: directory.appending(path: "Images/left-behind.png"))

        try await store.clear()
        let kept = try await store.search("", limit: 10)

        #expect(kept.map(\.text) == ["kept image", "pinned"])
        #expect(try images() == [try #require(kept[0].image).lastPathComponent])
    }

    @Test func leavesNoClearedTextInTheHistoryFile() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)
        let path = directory.appending(path: ClipboardStore.fileName)
        try Database(path: path.path(percentEncoded: false)).execute(
            """
            WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 2000)
            INSERT INTO clips (kind, text, date, pinned)
            SELECT 'text', 'secret ' || i || ' ' || hex(randomblob(50)), i, i = 1000 FROM n
            """)

        try await store.clear()
        let file = try Data(contentsOf: path)

        #expect(file.ranges(of: Data("secret ".utf8)).count == 1)
    }

    @Test func matchesWildcardCharactersLiterally() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)

        let texts = ["50% off", "500 off", "a_b", "axb", #"C:\temp"#, "nul\0inside"]
        for (index, text) in texts.enumerated() {
            try await store.add(
                Self.text(text, at: Double(index)), keeping: .init(days: .max, items: 100))
        }

        #expect(try await store.search("0%", limit: 10).map(\.text) == ["50% off"])
        #expect(try await store.search("a_", limit: 10).map(\.text) == ["a_b"])
        #expect(try await store.search(#"\t"#, limit: 10).map(\.text) == [#"C:\temp"#])
        #expect(try await store.search("OFF", limit: 10).map(\.text) == ["500 off", "50% off"])
        #expect(try await store.search("nul", limit: 10).map(\.text) == ["nul\0inside"])
    }

    @Test func searchesTenThousandItemsWithinOneFrame() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)
        try Database(
            path: directory.appending(path: ClipboardStore.fileName).path(percentEncoded: false)
        ).execute(
            """
            WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 10000)
            INSERT INTO clips (kind, text, date)
            SELECT 'text', 'clip ' || i || ' ' || hex(randomblob(CASE WHEN i % 100 = 0
                THEN 5000 ELSE 100 END)), i FROM n
            """)
        let budget = Duration.milliseconds(16)
        let clock = ContinuousClock()

        var times: [Duration] = []
        var found: [ClipboardStore.Entry] = []
        for _ in 1...10 {
            times.append(
                try await clock.measure { found = try await store.search("clip 9999 ", limit: 200) }
            )
        }

        #expect(found.map { $0.text.hasPrefix("clip 9999 ") } == [true])
        #expect(try #require(times.min()) < budget)
    }
}
