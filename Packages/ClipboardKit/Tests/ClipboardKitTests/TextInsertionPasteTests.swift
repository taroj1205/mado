import AppKit
import Carbon.HIToolbox
import Testing

@testable import ClipboardKit

@MainActor
@Suite struct TextInsertionPasteTests {
    private static let expansion = SnippetTemplate("Thanks!{cursor} Bye").expand(
        .init(fields: [:], date: "", time: "", clipboard: ""))

    private static func settled(_ pasteboard: NSPasteboard, on expected: String) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while pasteboard.string(forType: .string) != expected, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func pastesPlainTextAndPutsTheOldCopyBack() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("old", forType: .string)
        var posted: [CGEvent] = []
        var pastedText: String?
        let insertion = TextInsertion(
            pasteboard: pasteboard, restoreDelay: .zero, pasteTimeout: .zero
        ) { events in
            posted = events
            pastedText = pasteboard.string(forType: .string)
        }

        try await insertion.paste("{date} {cursor}")
        try await Self.settled(pasteboard, on: "old")

        let paste = Int64(try PasteTarget.commandV()[0].getIntegerValueField(.keyboardEventKeycode))
        #expect(posted.filter { $0.type == .keyDown }.count == 1)
        #expect(posted.first?.getIntegerValueField(.keyboardEventKeycode) == paste)
        #expect(pastedText == "{date} {cursor}")
        #expect(pasteboard.string(forType: .string) == "old")
    }

    @Test func aSecondPasteKeepsTheOriginalCopyInsteadOfTheFirstPastedText() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("old", forType: .string)
        var pasted: [String] = []
        let insertion = TextInsertion(
            pasteboard: pasteboard, restoreDelay: .milliseconds(50), pasteTimeout: .zero
        ) { _ in pasted.append(pasteboard.string(forType: .string) ?? "") }

        try await insertion.paste("first")
        try await insertion.paste("second")
        try await Self.settled(pasteboard, on: "old")

        #expect(pasted == ["first", "second"])
        #expect(pasteboard.string(forType: .string) == "old")
    }

    @Test func aPasteWaitsForASnippetsRestoreAndKeepsTheOriginalCopy() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("old", forType: .string)
        var pasted: [String] = []
        let insertion = TextInsertion(
            pasteboard: pasteboard, restoreDelay: .zero, pasteTimeout: .zero
        ) { _ in pasted.append(pasteboard.string(forType: .string) ?? "") }

        let inserted = try #require(await insertion.replace(";fu", with: Self.expansion) { true })
        let pasting = Task { try await insertion.paste("later") }
        try await Task.sleep(for: .milliseconds(200))
        let waiting = pasted
        await insertion.restore(inserted)
        try await pasting.value
        try await Self.settled(pasteboard, on: "old")

        #expect(waiting == ["Thanks! Bye"])
        #expect(pasted == ["Thanks! Bye", "later"])
        #expect(pasteboard.string(forType: .string) == "old")
    }

    @Test func stopsWaitingOnceSomethingElseIsCopied() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("old", forType: .string)
        let insertion = TextInsertion(
            pasteboard: pasteboard, restoreDelay: .zero, pasteTimeout: .seconds(60)
        ) { _ in
            pasteboard.clearContents()
            pasteboard.setString("newer", forType: .string)
        }

        try await insertion.paste("first")
        let start = ContinuousClock.now
        try await insertion.waitForRestore()

        #expect(ContinuousClock.now - start < .seconds(5))
        #expect(!insertion.isRestoring)
        #expect(pasteboard.string(forType: .string) == "newer")
    }
}
