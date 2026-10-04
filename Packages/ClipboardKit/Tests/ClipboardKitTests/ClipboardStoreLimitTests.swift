import AppKit
import Foundation
import Testing

@testable import ClipboardKit

@Suite struct ClipboardStoreLimitTests {
    private static let day: TimeInterval = 86_400
    private static let png = Data(repeating: 0x89, count: 10_000)

    private let directory = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)

    private static func text(_ text: String, at date: Date) -> Clip {
        Clip(.text, text: text, type: nil, data: nil, source: nil, date: date)
    }

    private func texts(in store: ClipboardStore) async throws -> [String] {
        try await store.search("", limit: 100).map(\.text)
    }

    private func historySize() throws -> Int {
        let path = directory.appending(path: ClipboardStore.fileName).path(percentEncoded: false)
        return try FileManager.default.attributesOfItem(atPath: path)[.size] as? Int ?? 0
    }

    @Test func keepsEverythingWithoutLimits() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)
        let none = ClipboardStore.Retention(period: nil, items: nil)
        let now = Date.now

        for (index, years) in [9.0, 2, 0].enumerated() {
            try await store.add(
                Self.text("item \(index)", at: now - years * 365 * Self.day), keeping: none)
        }
        try await store.prune(keeping: none, now: now)

        #expect(try await texts(in: store) == ["item 2", "item 1", "item 0"])
    }

    @Test func appliesOnlyTheLimitThatIsSet() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)
        let now = Date.now
        for (index, days) in [400.0, 40, 3, 2, 1].enumerated() {
            try await store.add(
                Self.text("item \(index)", at: now - days * Self.day),
                keeping: .init(period: nil, items: nil))
        }

        try await store.prune(keeping: .init(period: .init(1, .year), items: nil), now: now)
        let byAge = try await texts(in: store)
        try await store.prune(keeping: .init(period: nil, items: 2), now: now)

        #expect(byAge == ["item 4", "item 3", "item 2", "item 1"])
        #expect(try await texts(in: store) == ["item 4", "item 3"])
    }

    @Test func countsMonthsOnTheCalendar() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)
        let now = Date.now
        let monthAgo = try #require(Calendar.current.date(byAdding: .month, value: -1, to: now))
        let none = ClipboardStore.Retention(period: nil, items: nil)

        try await store.add(Self.text("older", at: monthAgo - 60), keeping: none)
        try await store.add(Self.text("newer", at: monthAgo + 60), keeping: none)
        try await store.prune(keeping: .init(period: .init(1, .month), items: nil), now: now)

        #expect(try await texts(in: store) == ["newer"])
    }

    @Test func keepsTheNewestCopiesMadeAtTheSameTime() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)
        let now = Date.now
        let none = ClipboardStore.Retention(period: nil, items: nil)
        for index in 1...5 {
            try await store.add(Self.text("item \(index)", at: now), keeping: none)
        }
        let first = try #require(try await store.search("item 1", limit: 1).first)
        try await store.setPinned(true, id: first.id)

        try await store.prune(keeping: .init(period: nil, items: 2), now: now)

        #expect(try await texts(in: store) == ["item 5", "item 4", "item 1"])
    }

    @Test func reportsTheItemsAndTheSpaceTheyTake() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)
        let none = ClipboardStore.Retention(period: nil, items: nil)
        try await store.add(
            Clip(.image, text: "", type: .png, data: Self.png, source: nil, date: .now),
            keeping: none)
        for index in 1...500 {
            try await store.add(
                Self.text(String(repeating: "\(index)", count: 100), at: .now), keeping: none)
        }
        let pinned = try #require(try await store.search("", limit: 1).first)
        try await store.setPinned(true, id: pinned.id)
        let fullSize = try historySize()

        let full = try await store.usage()
        try await store.clear()
        let cleared = try await store.usage()
        let clearedSize = try historySize()

        #expect(full.items == 501)
        #expect(full.bytes >= fullSize + Self.png.count)
        #expect(cleared.items == 1)
        #expect(cleared.bytes < full.bytes)
        #expect(clearedSize < fullSize / 4)
    }

    @Test func givesBackTheSpaceOfPrunedItemsWhenCompacted() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)
        let none = ClipboardStore.Retention(period: nil, items: nil)
        for index in 1...500 {
            try await store.add(
                Self.text(String(repeating: "\(index)", count: 100), at: .now), keeping: none)
        }
        let full = try historySize()

        try await store.prune(keeping: .init(period: nil, items: 10), now: .now)
        let pruned = try historySize()
        try await store.compact()

        #expect(pruned == full)
        #expect(try historySize() < full / 4)
        #expect(try await store.usage().items == 10)
    }

    @Test func indexesUnpinnedItemsInAHistorySavedEarlier() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appending(path: ClipboardStore.fileName).path(percentEncoded: false)
        try Database(path: path).execute(
            """
            CREATE TABLE clips (
                id INTEGER PRIMARY KEY, kind TEXT NOT NULL, text TEXT NOT NULL, type TEXT,
                data BLOB, image TEXT, source TEXT, date REAL NOT NULL,
                pinned INTEGER NOT NULL DEFAULT 0
            );
            PRAGMA user_version = 2;
            """)

        _ = try ClipboardStore(directory: directory)
        let indexes = try Database(path: path).rows(
            "SELECT name FROM sqlite_master WHERE type = 'index'", []
        ) { $0.string(0) }

        #expect(indexes.contains("clips_unpinned_by_date"))
    }
}
