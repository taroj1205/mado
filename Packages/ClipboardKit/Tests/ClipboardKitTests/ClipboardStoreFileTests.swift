import AppKit
import Foundation
import Testing

@testable import ClipboardKit

@Suite struct ClipboardStoreFileTests {
    private let directory = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)

    @MainActor
    @Test func keepsFileNamesThatContainALineBreak() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)
        let files = [URL(filePath: "/tmp/two\nlines.txt"), URL(filePath: "/tmp/c.txt")]
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.writeObjects(files.map { $0 as any NSPasteboardWriting })
        let clip = try #require(Clip(reading: pasteboard, source: nil, at: .now))

        try await store.add(clip, keeping: ClipboardStore.Retention())
        let entry = try #require(try await store.search("lines", limit: 1).first)
        try entry.copy(data: nil, to: pasteboard)

        #expect(entry.files == files)
        #expect(
            pasteboard.pasteboardItems?.compactMap { $0.string(forType: .fileURL) }
                == files.map(\.absoluteString))
    }

    @Test func readsFilesSavedBeforeTheirPathList() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)
        try Database(
            path: directory.appending(path: ClipboardStore.fileName).path(percentEncoded: false)
        ).execute(
            """
            INSERT INTO clips (kind, text, date)
            VALUES ('file', '/tmp/a' || char(10) || '/tmp/b', 1)
            """)

        let entry = try #require(try await store.search("", limit: 1).first)

        #expect(entry.files == [URL(filePath: "/tmp/a"), URL(filePath: "/tmp/b")])
    }
}
