import AppKit
import Testing

@testable import ClipboardKit

@MainActor
@Suite struct ClipSavedTextTests {
    private func written(_ text: String, source: String?) throws -> NSPasteboard {
        let pasteboard = NSPasteboard.withUniqueName()
        try PasteTarget.write(Clip.savedTextItems(text, source: source), to: pasteboard)
        return pasteboard
    }

    @Test func writesTheTextWithoutMarkingItTransientSoHistoryKeepsIt() throws {
        let pasteboard = try written("merged\ntext", source: "com.example.mado")
        defer { pasteboard.releaseGlobally() }
        #expect(pasteboard.string(forType: .string) == "merged\ntext")
        #expect(pasteboard.types?.contains(PasteboardWatch.transientType) != true)
        let watch = PasteboardWatch(pasteboard: pasteboard)
        #expect(!watch.holdsPrivateData)
    }

    @Test func namesTheAppThatMadeTheTextAsItsSource() throws {
        let pasteboard = try written("text", source: "com.example.mado")
        defer { pasteboard.releaseGlobally() }
        #expect(
            PasteboardWatch.sourceApps(of: pasteboard, frontmost: "com.example.notes", before: nil)
                == ["com.example.mado"])
    }

    @Test func historyReadsItBackAsPlainText() throws {
        let pasteboard = try written("one\ntwo", source: nil)
        defer { pasteboard.releaseGlobally() }
        let clip = try #require(Clip(reading: pasteboard, source: nil, at: .now))
        #expect(clip.kind == .text)
        #expect(clip.text == "one\ntwo")
    }
}
