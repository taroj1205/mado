import AppKit
import CoreGraphics
import CoreML
import CoreText
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import ClipboardKit

@Suite struct ImageTextTests {
    private static let fontSize: CGFloat = 28
    private static let hasNeuralEngine = MLComputeDevice.allComputeDevices.contains { device in
        if case .neuralEngine = device { true } else { false }
    }

    private let directory = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)

    private static func image(width: Int, height: Int, lines: [String]) throws -> CGImage {
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
        return try #require(context.makeImage())
    }

    private static func png(width: Int, height: Int, lines: [String]) throws -> Data {
        let image = try image(width: width, height: height, lines: lines)
        let data = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @Test(
        .enabled(
            if: hasNeuralEngine,
            "Vision's accurate text recognition throws on the CI runner, which has no Neural Engine"
        ))
    func findsAScreenshotByTheTextInIt() async throws {
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

    @Test func readsTheEnglishLinesOnAnyMac() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appending(path: "screenshot.png")
        let lines = [
            "Boarding pass", "Flight NZ 99 Gate 16", "Booking ref QX7K2M", "東京駅で待ち合わせ",
        ]
        try Self.png(width: 1_440, height: 900, lines: lines).write(to: file)

        #expect(try await ImageText.recognize(at: file).contains("QX7K2M"))
    }

    @Test func readsAnImageInMemoryAndNamesItsLanguage() async throws {
        let lines = ["Please keep your boarding pass", "until you reach the gate"]

        let recognition = try await ImageText.recognize(
            Self.image(width: 1_440, height: 300, lines: lines))

        #expect(recognition.text.contains("boarding pass"))
        #expect(recognition.language == "en")
    }

    @Test func namesJapaneseWhenThatIsWhatTheImageSays() async throws {
        let recognition = try await ImageText.recognize(
            Self.image(width: 1_440, height: 300, lines: ["東京駅で待ち合わせ", "改札口の前です"]))

        #expect(recognition.text.contains("東京駅"))
        #expect(recognition.language == "ja")
    }

    @Test func putsTextOnTheSameRowBackOnOneLine() {
        let pieces = [
            ImageText.Piece(box: CGRect(x: 0.73, y: 0.38, width: 0.13, height: 0.19), text: "6.80"),
            ImageText.Piece(
                box: CGRect(x: 0.06, y: 0.72, width: 0.35, height: 0.19), text: "Flat white"),
            ImageText.Piece(
                box: CGRect(x: 0.05, y: 0.39, width: 0.51, height: 0.19), text: "Almond croissant"),
            ImageText.Piece(box: CGRect(x: 0.73, y: 0.69, width: 0.13, height: 0.20), text: "5.50"),
            ImageText.Piece(
                box: CGRect(x: 0.05, y: 0.07, width: 0.29, height: 0.16), text: "TOTAL NZD"),
        ]

        #expect(
            ImageText.lines(of: pieces)
                == "Flat white 5.50\nAlmond croissant 6.80\nTOTAL NZD")
    }

    @Test func keepsLinesApartWhenTheyDoNotOverlapVertically() {
        let pieces = [
            ImageText.Piece(box: CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.2), text: "second"),
            ImageText.Piece(box: CGRect(x: 0.1, y: 0.5, width: 0.5, height: 0.2), text: "first"),
        ]

        #expect(ImageText.lines(of: pieces) == "first\nsecond")
        #expect(ImageText.lines(of: []).isEmpty)
    }

    @Test func findsNothingInABlankImage() async throws {
        let recognition = try await ImageText.recognize(
            Self.image(width: 400, height: 200, lines: []))

        #expect(recognition.text.isEmpty)
        #expect(recognition.language == nil)
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
