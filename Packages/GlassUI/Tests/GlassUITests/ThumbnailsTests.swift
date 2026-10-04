import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct ThumbnailsTests {
    private let folder = FileManager.default.temporaryDirectory.appending(
        path: "ThumbnailsTests-\(UUID().uuidString)")
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 280, height: 36),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)

    private static func item(_ id: String, thumbnail: URL? = nil) -> ResultList.Item {
        .init(
            id: id, title: "Image", subtitle: "", kind: "Image", symbol: "photo", action: "",
            thumbnail: thumbnail)
    }

    private static func side(in cell: GlyphCell) -> Int {
        Int((GlyphCell.thumbnailSize * (unsafe cell.window?.backingScaleFactor ?? 0)).rounded(.up))
    }

    private func image(_ name: String, width: Int, height: Int) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let rep = try #require(
            unsafe NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                bytesPerRow: 0, bitsPerPixel: 0))
        let url = folder.appending(path: name)
        try #require(rep.representation(using: .png, properties: [:])).write(to: url)
        return url
    }

    private func cell() -> GlyphCell {
        let cell = GlyphCell()
        cell.thumbnails = Thumbnails()
        panel.contentView = cell
        return cell
    }

    @Test func downsamplesSoTheShortSideFillsTheSquare() throws {
        let wide = try image("wide.png", width: 400, height: 200)
        let tall = try image("tall.png", width: 100, height: 300)
        defer { try? FileManager.default.removeItem(at: folder) }

        let fromWide = try #require(Thumbnails.decode(.init(url: wide, side: 48)))
        let fromTall = try #require(Thumbnails.decode(.init(url: tall, side: 48)))

        #expect((fromWide.width, fromWide.height) == (96, 48))
        #expect((fromTall.width, fromTall.height) == (48, 144))
    }

    @Test func aVeryWideImageStopsAtFourTimesTheSquare() throws {
        let strip = try image("strip.png", width: 2_000, height: 100)
        defer { try? FileManager.default.removeItem(at: folder) }

        let thumbnail = try #require(Thumbnails.decode(.init(url: strip, side: 48)))

        #expect(thumbnail.width == 192)
    }

    @Test func aMissingOrUnreadableFileLoadsNothing() async throws {
        let text = folder.appending(path: "notes.txt")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("not an image".utf8).write(to: text)
        defer { try? FileManager.default.removeItem(at: folder) }
        let thumbnails = Thumbnails()

        #expect(
            await thumbnails.load(.init(url: folder.appending(path: "gone.png"), side: 48)) == nil)
        #expect(await thumbnails.load(.init(url: text, side: 48)) == nil)
    }

    @Test func aSecondLoadComesFromTheCacheEvenAfterTheFileIsGone() async throws {
        let url = try image("cached.png", width: 64, height: 64)
        let thumbnails = Thumbnails()
        let request = Thumbnails.Request(url: url, side: 48)

        #expect(thumbnails.cached(request) == nil)
        let first = try #require(await thumbnails.load(request))
        try FileManager.default.removeItem(at: folder)

        #expect(thumbnails.cached(request) === first)
        #expect(await thumbnails.load(request) === first)
        #expect(thumbnails.cached(.init(url: url, side: 96)) == nil)
    }

    @Test func aCancelledLoadLeavesTheCacheAlone() async throws {
        let url = try image("cancelled.png", width: 64, height: 64)
        defer { try? FileManager.default.removeItem(at: folder) }
        let thumbnails = Thumbnails()
        let request = Thumbnails.Request(url: url, side: 48)

        let loading = Task { await thumbnails.load(request) }
        loading.cancel()
        _ = await loading.value

        #expect(thumbnails.cached(request) == nil)
    }

    @Test func anImageRowShowsItsThumbnailInPlaceOfTheGlyph() async throws {
        let url = try image("row.png", width: 300, height: 200)
        defer { try? FileManager.default.removeItem(at: folder) }
        let cell = cell()

        cell.show(Self.item("row", thumbnail: url))
        #expect(!cell.glyph.isHidden)
        #expect(cell.thumbnail.isHidden)
        await cell.loading?.value

        #expect(cell.glyph.isHidden)
        #expect(!cell.thumbnail.isHidden)
        #expect(cell.thumbnail.image?.height == Self.side(in: cell))
        #expect(cell.accessibilityLabel() == "Image")
    }

    @Test func keepsTheGlyphWhenTheFileIsMissingAndForOtherKinds() async {
        let cell = cell()

        cell.show(Self.item("gone", thumbnail: folder.appending(path: "gone.png")))
        await cell.loading?.value
        #expect(!cell.glyph.isHidden)
        #expect(cell.thumbnail.isHidden)

        cell.show(
            .init(
                id: "text", title: "hello", subtitle: "", kind: "Text", symbol: "text.alignleft",
                action: ""))
        #expect(cell.loading == nil)
        #expect(!cell.glyph.isHidden)
        #expect(cell.thumbnail.isHidden)
        #expect(cell.accessibilityLabel() == "hello, Text")
    }

    @Test func aReusedCellIgnoresTheThumbnailItWasLoadingBefore() async throws {
        let old = try image("old.png", width: 400, height: 200)
        let new = try image("new.png", width: 100, height: 300)
        let slow = try image("slow.png", width: 200, height: 200)
        defer { try? FileManager.default.removeItem(at: folder) }
        let cell = cell()
        let shown = try #require(
            await cell.thumbnails.load(.init(url: new, side: Self.side(in: cell))))

        cell.show(Self.item("old", thumbnail: old))
        let stale = try #require(cell.loading)
        cell.show(Self.item("new", thumbnail: new))
        await stale.value

        #expect(cell.thumbnail.image === shown)

        cell.show(Self.item("slow", thumbnail: slow))
        let late = try #require(cell.loading)
        cell.show(
            .init(id: "text", title: "hi", subtitle: "", kind: "Text", symbol: "", action: ""))
        await late.value

        #expect(cell.thumbnail.image == nil)
        #expect(cell.thumbnail.isHidden)
        #expect(!cell.glyph.isHidden)
    }

    @Test func leavingTheWindowDropsTheImageAndComingBackRestoresIt() async throws {
        let url = try image("back.png", width: 64, height: 64)
        defer { try? FileManager.default.removeItem(at: folder) }
        let cell = cell()
        cell.show(Self.item("back", thumbnail: url))
        await cell.loading?.value
        let loaded = try #require(cell.thumbnail.image)

        panel.contentView = nil
        #expect(cell.thumbnail.image == nil)
        panel.contentView = cell

        #expect(cell.loading == nil)
        #expect(cell.thumbnail.image === loaded)
    }
}
