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
            text.details(source: "Mail", now: now, calendar: calendar).map(\.value) == [
                "Mail", "Text", "35", "6", "Today at \(time)",
            ])
        let link = Self.entry(.url, "https://developer.apple.com/documentation/appkit")
        #expect(
            link.details(source: "Safari", now: now, calendar: calendar).map(\.name) == [
                "Source", "Content type", "Characters", "Host", "Copied",
            ])
        #expect(
            link.details(source: "Safari", now: now, calendar: calendar)[3].value
                == "developer.apple.com")
        let colour = Self.entry(.color, "#0A84FF")
        let values = colour.details(source: "Unknown", now: now, calendar: calendar).map(\.value)
        #expect(values.dropLast() == ["Unknown", "Color", "#0A84FF", "10, 132, 255"])
        let files = Self.entry(.file, "/tmp/a\n/tmp/b")
        #expect(files.details(source: "Finder", now: now, calendar: calendar)[2].value == "2")
        let yesterday = Self.entry(.text, "x", at: now - 24 * Self.hour)
        #expect(
            yesterday.details(source: "Notes", now: now, calendar: calendar).last?.value
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

        let details = Self.entry(.image, "", image: file)
            .details(source: "Screenshot", now: now, calendar: calendar)

        #expect(details.map(\.name) == ["Source", "Content type", "Dimensions", "Size", "Copied"])
        #expect(details[2].value == "\(bitmap.pixelsWide) × \(bitmap.pixelsHigh)")
        #expect(
            details[3].value
                == ByteCountFormatter.string(fromByteCount: Int64(png.count), countStyle: .file))
        #expect(
            Self.entry(.image, "", image: file.appending(path: "missing")).details(
                source: "Screenshot", now: now, calendar: calendar
            ).count == 3)
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
}
