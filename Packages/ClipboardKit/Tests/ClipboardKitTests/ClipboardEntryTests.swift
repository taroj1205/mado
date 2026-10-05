import AppKit
import Foundation
import Testing

@testable import ClipboardKit

@MainActor
@Suite struct ClipboardEntryTests {
    private static let hour: TimeInterval = 3_600

    private let pasteboard = NSPasteboard(name: .init(UUID().uuidString))
    private let calendar: Calendar
    private let now: Date

    init() throws {
        calendar = Calendar(identifier: .gregorian)
        let day = try #require(
            calendar.dateInterval(of: .day, for: Date(timeIntervalSince1970: 1_790_000_000)))
        now = day.start + 11 * Self.hour
    }

    private static func entry(
        _ kind: Clip.Kind, _ text: String, type: String? = nil, image: URL? = nil,
        at date: Date = .now
    ) -> ClipboardStore.Entry {
        ClipboardStore.Entry(
            id: 1, kind: kind, text: text, type: type,
            files: kind == .file
                ? text.split(separator: "\n").map { URL(filePath: String($0)) } : [],
            image: image, source: nil, date: date, pinned: false)
    }

    private func details(
        of entry: ClipboardStore.Entry, from source: String, counted: Bool = true
    ) -> [ClipboardStore.Entry.Detail] {
        entry.details(
            source: source, now: now, calendar: calendar, counts: counted ? entry.counts : nil)
    }

    @Test func titlesARowByItsFirstLineOrItsFileNames() {
        #expect(Self.entry(.text, "\n  first line  \nsecond").title == "first line")
        #expect(Self.entry(.richText, "bold").title == "bold")
        #expect(Self.entry(.file, "/tmp/a.txt\n/Users/me/b.png").title == "a.txt, b.png")
        #expect(Self.entry(.image, "").title == "Image")
        #expect(Self.entry(.text, String(repeating: "x", count: 500)).title.count == 200)
    }

    @Test func previewsColoursWithTheirRGB() {
        #expect(Self.entry(.color, "#0A84FF").preview == "#0A84FF\nrgb(10, 132, 255)")
        #expect(Self.entry(.color, "#0a84ff80").preview == "#0a84ff80\nrgb(10, 132, 255)")
        #expect(Self.entry(.text, "#0A84FF").rgb == nil)
        #expect(Self.entry(.image, "").preview.isEmpty)
        #expect(Self.entry(.url, "https://apple.com").preview == "https://apple.com")
    }

    @Test func describesEachKind() {
        let copied = now - Self.hour
        let time = copied.formatted(date: .omitted, time: .shortened)
        let text = Self.entry(.text, "Thanks! I’ll send the file tonight.", at: copied)
        #expect(
            details(of: text, from: "Mail").map(\.value) == [
                "Mail", "Text", "35", "6", "Today at \(time)",
            ])
        let link = Self.entry(.url, "https://developer.apple.com/documentation/appkit")
        #expect(
            details(of: link, from: "Safari").map(\.name) == [
                "Source", "Content type", "Characters", "Host", "Copied",
            ])
        #expect(
            details(of: link, from: "Safari")[3].value
                == "developer.apple.com")
        let colour = Self.entry(.color, "#0A84FF")
        let values = details(of: colour, from: "Unknown").map(\.value)
        #expect(values.dropLast() == ["Unknown", "Color", "#0A84FF", "10, 132, 255"])
        let files = Self.entry(.file, "/tmp/a\n/tmp/b")
        #expect(details(of: files, from: "Finder")[2].value == "2")
        let yesterday = Self.entry(.text, "x", at: now - 24 * Self.hour)
        #expect(
            details(of: yesterday, from: "Notes").last?.value
                .hasPrefix("Yesterday at ") == true)
    }

    @Test func describesAnImageByItsSizeOnDisk() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).png")
        defer { try? FileManager.default.removeItem(at: file) }
        let image = NSImage(size: NSSize(width: 3, height: 2), flipped: false) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
            return true
        }
        let bitmap = try #require(image.tiffRepresentation.flatMap(NSBitmapImageRep.init))
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: file)

        let shown = details(of: Self.entry(.image, "", image: file), from: "Screenshot")

        #expect(shown.map(\.name) == ["Source", "Content type", "Dimensions", "Size", "Copied"])
        #expect(shown[2].value == "\(bitmap.pixelsWide) × \(bitmap.pixelsHigh)")
        #expect(
            shown[3].value
                == ByteCountFormatter.string(fromByteCount: Int64(png.count), countStyle: .file))
        #expect(
            details(
                of: Self.entry(.image, "", image: file.appending(path: "missing")),
                from: "Screenshot"
            )
            .count == 3)
    }

    @Test func showsACopiedImageOrVideoFileAsAThumbnail() {
        let png = "/tmp/Screenshot.png"
        let video = "/tmp/Recording.mp4"
        let notes = "/tmp/Notes.txt"

        #expect(Self.entry(.file, png).thumbnail == URL(filePath: png))
        #expect(Self.entry(.file, video).thumbnail == URL(filePath: video))
        #expect(Self.entry(.file, notes).thumbnail == nil)
        #expect(Self.entry(.file, "\(png)\n\(png)").thumbnail == nil)
        let saved = URL(filePath: "/tmp/Images/1.png")
        #expect(Self.entry(.image, "", image: saved).thumbnail == saved)
        #expect(Self.entry(.text, png).thumbnail == nil)
    }

    @Test func countsShortTextRightAwayAndLeavesLongTextForLater() {
        let short = Self.entry(.text, "Thanks! I’ll send the file tonight.")
        let long = Self.entry(.text, String(repeating: "word ", count: 20_001))
        let link = Self.entry(.url, "https://apple.com")

        #expect(short.quickCounts == .init(characters: 35, words: 6))
        #expect(long.quickCounts == nil)
        #expect(long.counts == .init(characters: 100_005, words: 20_001))
        let pending = details(of: long, from: "Notes", counted: false).map(\.value)
        #expect(pending[2...3] == ["…", "…"])
        #expect(details(of: link, from: "Safari", counted: false)[2].value == "…")
    }

    @Test func countsInTheBackgroundUnlessCancelled() async {
        let long = Self.entry(.text, String(repeating: "word ", count: 20_001))

        #expect(await long.backgroundCounts() == long.counts)
        #expect(long.count { true }.words == 1)
        let cancelled = Task { await long.backgroundCounts() }
        cancelled.cancel()
        #expect(await cancelled.value == nil)
    }

    @Test func groupsEntriesByDayNewestFirst() {
        let entries = [now, now - Self.hour, now - 30 * Self.hour].map { date in
            Self.entry(.text, "x", at: date)
        }

        let days = ClipboardStore.Entry.byDay(entries, calendar: calendar)

        #expect(days.map(\.entries.count) == [2, 1])
        #expect(days.map(\.day) == [now, now - 30 * Self.hour].map(calendar.startOfDay))
    }

    @Test func copiesTextLinksAndRichTextWithoutSavingThemAgain() throws {
        try Self.entry(.url, "https://apple.com").copy(data: nil, to: pasteboard)
        #expect(pasteboard.string(forType: .URL) == "https://apple.com")
        #expect(pasteboard.string(forType: .string) == "https://apple.com")
        #expect(pasteboard.types?.contains(PasteboardWatch.transientType) == true)

        let rtf = Data(#"{\rtf1 bold}"#.utf8)
        try Self.entry(.richText, "bold", type: NSPasteboard.PasteboardType.rtf.rawValue)
            .copy(data: rtf, to: pasteboard)
        #expect(pasteboard.data(forType: .rtf) == rtf)
        #expect(pasteboard.string(forType: .string) == "bold")
    }

    @Test func copiesFilesAndImages() throws {
        try Self.entry(.file, "/tmp/a b.txt\n/tmp/c.txt").copy(data: nil, to: pasteboard)
        let urls = pasteboard.pasteboardItems?.compactMap { $0.string(forType: .fileURL) }
        #expect(urls == ["file:///tmp/a%20b.txt", "file:///tmp/c.txt"])

        let file = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).png")
        defer { try? FileManager.default.removeItem(at: file) }
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        try png.write(to: file)
        try Self.entry(.image, "", type: NSPasteboard.PasteboardType.png.rawValue, image: file)
            .copy(data: nil, to: pasteboard)
        #expect(pasteboard.data(forType: .png) == png)
        #expect(throws: (any Error).self) {
            try Self.entry(.image, "", type: "public.png", image: file.appending(path: "gone"))
                .copy(data: nil, to: pasteboard)
        }
    }

    @Test func pastesAsPlainTextWithoutTheStyleOrLinkTypes() throws {
        let rtf = NSPasteboard.PasteboardType.rtf.rawValue
        for entry in [
            Self.entry(.richText, "bold", type: rtf), Self.entry(.url, "https://apple.com"),
            Self.entry(.file, "/tmp/a b.txt\n/tmp/c.txt"), Self.entry(.color, "#0A84FF"),
        ] {
            let items = try entry.plainTextItems()
            #expect(items.count == 1)
            #expect(Set(items.first?.types ?? []) == [.string, PasteboardWatch.transientType])
            #expect(items.first?.string(forType: .string) == entry.text)
        }
        let image = Self.entry(.image, "recognized words", type: "public.png")
        #expect(image.plainText == nil)
        #expect(throws: PasteTarget.Failure.notWritten) { try image.plainTextItems() }
    }
}
