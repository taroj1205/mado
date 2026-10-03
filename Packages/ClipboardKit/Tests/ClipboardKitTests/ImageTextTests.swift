import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import ClipboardKit

@Suite struct ImageTextTests {
    private static let fontSize: CGFloat = 28

    private let directory = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)

    static func png(width: Int, height: Int, lines: [String]) throws -> Data {
        let drawing = unsafe CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        let context = try #require(drawing)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let font = CTFontCreateUIFontForLanguage(.system, fontSize, nil)
        for (index, line) in lines.enumerated() {
            let text = NSAttributedString(
                string: line,
                attributes: [
                    NSAttributedString.Key(kCTFontAttributeName as String): font as Any,
                    NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(
                        gray: 0, alpha: 1),
                ])
            context.textPosition = CGPoint(
                x: fontSize * 2, y: CGFloat(height) - fontSize * 2 * CGFloat(index + 1))
            CTLineDraw(CTLineCreateWithAttributedString(text), context)
        }
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @Test func findsAScreenshotByTheTextInIt() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ClipboardStore(directory: directory)
        let lines = [
            "Boarding pass", "Flight NZ 99 Gate 16", "Booking ref QX7K2M", "東京駅で待ち合わせ",
        ]
        let screenshot = try Self.png(width: 1_440, height: 900, lines: lines)
        try await store.add(
            Clip(.image, text: "", type: .png, data: screenshot, source: nil, date: .now),
            keeping: ClipboardStore.Retention())
        try await store.add(
            Clip(.text, text: "notes", type: nil, data: nil, source: nil, date: .now + 1),
            keeping: ClipboardStore.Retention())

        #expect(try await store.search("QX7K2M", limit: 10).isEmpty)

        try await store.recognizeImages()

        #expect(try await store.search("QX7K2M", limit: 10).map(\.kind) == [.image])
        #expect(try await store.search("待ち合わせ", limit: 10).map(\.kind) == [.image])
        #expect(try await store.search("gate 16", limit: 10, kind: .image).count == 1)
        #expect(try await store.search("Departure", limit: 10).isEmpty)
        #expect(try await store.search("", limit: 10).map(\.kind) == [.text, .image])
    }

    @Test func scalesALargeImageDownBeforeReadingIt() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let large = directory.appending(path: "large.png")
        let small = directory.appending(path: "small.png")
        try Self.png(width: 9_000, height: 3_000, lines: []).write(to: large)
        try Self.png(width: 800, height: 300, lines: []).write(to: small)

        let scaled = try #require(ImageText.image(at: large))
        let kept = try #require(ImageText.image(at: small))

        #expect(scaled.width == ImageText.longestSide)
        #expect(scaled.height == ImageText.longestSide / 3)
        #expect(kept.width == 800)
        #expect(kept.height == 300)
    }

    @Test func refusesAFileThatIsNotAnImage() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appending(path: "broken.png")
        try Data("not an image".utf8).write(to: file)

        await #expect(throws: ImageText.Unreadable.self) {
            try await ImageText.recognize(at: file)
        }
    }
}
