import AppKit
import Foundation
import Testing

@testable import ClipboardKit

@MainActor
@Suite struct ClipTests {
    private static let date = Date(timeIntervalSince1970: 1_000)

    private static func clip(_ write: (NSPasteboard) -> Void) -> Clip? {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        write(pasteboard)
        return Clip(reading: pasteboard, source: "com.example.app", at: date)
    }

    @Test func keepsPlainText() throws {
        let clip = try #require(
            Self.clip { $0.setString("Meeting moved to 3:30", forType: .string) })

        #expect(
            clip
                == Clip(
                    .text, text: "Meeting moved to 3:30", type: nil, data: nil,
                    source: "com.example.app", date: Self.date))
    }

    @Test func keepsRichTextWithItsFormatting() throws {
        let rtf = Data(#"{\rtf1 {\b bold}}"#.utf8)
        let clip = try #require(
            Self.clip { pasteboard in
                pasteboard.setString("bold", forType: .string)
                pasteboard.setData(rtf, forType: .rtf)
            })

        #expect(clip.kind == .richText)
        #expect(clip.text == "bold")
        #expect(clip.type == NSPasteboard.PasteboardType.rtf.rawValue)
        #expect(clip.data == rtf)
    }

    @Test func keepsAnImageThatHasNoText() throws {
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        let clip = try #require(Self.clip { $0.setData(png, forType: .png) })

        #expect(clip.kind == .image)
        #expect(clip.type == NSPasteboard.PasteboardType.png.rawValue)
        #expect(clip.data == png)
    }

    @Test func keepsFilesAsTheirPaths() throws {
        let files = [URL(filePath: "/tmp/a.txt"), URL(filePath: "/tmp/b c.txt")]
        let clip = try #require(
            Self.clip { $0.writeObjects(files.map { $0 as any NSPasteboardWriting }) })

        #expect(clip.kind == .file)
        #expect(clip.text == "/tmp/a.txt\n/tmp/b c.txt")
        #expect(clip.data == Data("/tmp/a.txt\0/tmp/b c.txt".utf8))
    }

    @Test(arguments: ["https://developer.apple.com/documentation/appkit", " http://a.io "])
    func keepsWebLinksAsURLs(_ link: String) throws {
        let clip = try #require(Self.clip { $0.setString(link, forType: .string) })

        #expect(clip.kind == .url)
        #expect(clip.text == link.trimmingCharacters(in: .whitespaces))
    }

    @Test(arguments: ["see https://a.io", "mailto:a@b.c", "#0A84FF", "#0a84ff80"])
    func tellsLinksFromColoursAndText(_ text: String) throws {
        let clip = try #require(Self.clip { $0.setString(text, forType: .string) })

        #expect(clip.kind == (text.hasPrefix("#") ? .color : .text))
    }

    @Test func keepsACopiedColourAsHex() throws {
        let clip = try #require(
            Self.clip { pasteboard in
                pasteboard.writeObjects([
                    NSColor(srgbRed: 10 / 255, green: 132 / 255, blue: 1, alpha: 1)
                ])
            })

        #expect(clip.kind == .color)
        #expect(clip.text == "#0A84FF")
        #expect(clip.data != nil)
    }

    @Test func skipsCopiesWithNothingToKeep() {
        #expect(Self.clip { $0.setString(" \n", forType: .string) } == nil)
        #expect(Self.clip { $0.setData(Data([1]), forType: .pdf) } == nil)
    }
}
