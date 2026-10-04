import AppKit
import Carbon.HIToolbox
import Testing

@testable import ClipboardKit

@MainActor
@Suite struct TextInsertionTests {
    private static let expansion = SnippetTemplate("Thanks!{cursor} Bye").expand(
        .init(fields: [:], date: "", time: "", clipboard: ""))

    private static func keys(_ events: [CGEvent]) -> [Int64] {
        events.filter { $0.type == .keyDown }.map { $0.getIntegerValueField(.keyboardEventKeycode) }
    }

    private static func text(of event: CGEvent) -> String {
        var length = 0
        var units = [UniChar](repeating: 0, count: 20)
        unsafe event.keyboardGetUnicodeString(
            maxStringLength: units.count, actualStringLength: &length, unicodeString: &units)
        return String(decoding: units.prefix(length), as: UTF16.self)
    }

    @Test func deletesTheKeywordPastesAndPutsTheCaretBack() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("old", forType: .string)
        var posted: [CGEvent] = []
        var pastedText: String?
        var pastedTransient = false
        let insertion = TextInsertion(
            pasteboard: pasteboard, restoreDelay: .zero, pasteTimeout: .zero
        ) { events in
            posted = events
            pastedText = pasteboard.string(forType: .string)
            pastedTransient = pasteboard.types?.contains(PasteboardWatch.transientType) == true
        }

        let inserted = try #require(await insertion.replace(";fu", with: Self.expansion) { true })
        let pastedFirst = pasteboard.string(forType: .string)
        await insertion.restore(inserted)

        let paste = Int64(try PasteTarget.commandV()[0].getIntegerValueField(.keyboardEventKeycode))
        let delete = Int64(kVK_Delete)
        let left = Int64(kVK_LeftArrow)
        #expect(Self.keys(posted) == [delete, delete, delete, paste, left, left, left, left])
        #expect(posted.allSatisfy(Keystrokes.isPosted))
        #expect(pastedText == "Thanks! Bye")
        #expect(pastedTransient)
        #expect(pastedFirst == "Thanks! Bye")
        #expect(pasteboard.string(forType: .string) == "old")
        #expect(pasteboard.types?.contains(PasteboardWatch.transientType) == true)
        #expect(inserted.length == 11)
        #expect(inserted.caretBack == 4)
        #expect(inserted.replaced == ";fu")
    }

    @Test func waitsForThePasteToReadTheSnippetBeforePuttingTheOldCopyBack() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("old", forType: .string)
        var posted: [CGEvent] = []
        let insertion = TextInsertion(
            pasteboard: pasteboard, restoreDelay: .zero, pasteTimeout: .seconds(60)
        ) { posted = $0 }

        let inserted = try #require(await insertion.replace(";fu", with: Self.expansion) { true })
        let restoring = Task { await insertion.restore(inserted) }
        try await Task.sleep(for: .milliseconds(300))
        let changesBeforePaste = pasteboard.changeCount
        let pasted = pasteboard.string(forType: .string)
        await restoring.value

        #expect(!posted.isEmpty)
        #expect(changesBeforePaste == inserted.changeCount)
        #expect(pasted == "Thanks! Bye")
        #expect(pasteboard.string(forType: .string) == "old")
    }

    @Test func putsTheOldCopyBackWhenNothingPastes() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("old", forType: .string)
        var posted: [CGEvent] = []
        let insertion = TextInsertion(
            pasteboard: pasteboard, restoreDelay: .zero, pasteTimeout: .milliseconds(100)
        ) { posted = $0 }
        let start = ContinuousClock.now

        let inserted = try #require(await insertion.replace(";fu", with: Self.expansion) { true })
        await insertion.restore(inserted)

        #expect(!posted.isEmpty)
        #expect(ContinuousClock.now - start >= .milliseconds(100))
        #expect(pasteboard.string(forType: .string) == "old")
    }

    @Test func leavesTheCaretAtTheEndPastTheKeyLimitAndOffersNoUndo() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        var posted: [CGEvent] = []
        let insertion = TextInsertion(
            pasteboard: pasteboard, restoreDelay: .zero, pasteTimeout: .zero
        ) { posted = $0 }
        let tail = String(repeating: "x", count: TextInsertion.keyLimit + 1)
        let long = SnippetTemplate("{cursor}" + tail).expand(
            .init(fields: [:], date: "", time: "", clipboard: ""))
        let short = SnippetTemplate("{cursor}" + tail.dropFirst()).expand(
            .init(fields: [:], date: "", time: "", clipboard: ""))

        let longInserted = try #require(await insertion.replace(";fu", with: long) { true })
        let longArrows = Self.keys(posted).filter { $0 == Int64(kVK_LeftArrow) }.count
        let shortInserted = try #require(await insertion.replace(";fu", with: short) { true })
        let shortArrows = Self.keys(posted).filter { $0 == Int64(kVK_LeftArrow) }.count

        #expect(longArrows == 0)
        #expect(longInserted.caretBack == 0)
        #expect(!longInserted.canUndo)
        #expect(shortArrows == TextInsertion.keyLimit)
        #expect(shortInserted.canUndo)
    }

    @Test func clearsAPasteboardThatWasEmpty() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        var posted: [CGEvent] = []
        let insertion = TextInsertion(
            pasteboard: pasteboard, restoreDelay: .zero, pasteTimeout: .zero
        ) { posted = $0 }

        let inserted = try #require(await insertion.replace("", with: Self.expansion) { true })
        await insertion.restore(inserted)

        #expect(pasteboard.pasteboardItems?.isEmpty == true)
        #expect(!posted.isEmpty)
    }

    @Test func leavesANewerCopyAlone() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("old", forType: .string)
        let insertion = TextInsertion(
            pasteboard: pasteboard, restoreDelay: .zero, pasteTimeout: .zero
        ) { _ in
            pasteboard.clearContents()
            pasteboard.setString("copied meanwhile", forType: .string)
        }

        let inserted = try #require(await insertion.replace("", with: Self.expansion) { true })
        await insertion.restore(inserted)

        #expect(pasteboard.string(forType: .string) == "copied meanwhile")
    }

    @Test func checksTheTargetOnlyAfterSavingTheClipboard() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let promised = TextInsertion.LazyText("old")
        let item = NSPasteboardItem()
        #expect(item.setDataProvider(promised, forTypes: [.string]))
        pasteboard.clearContents()
        #expect(pasteboard.writeObjects([item]))
        let before = pasteboard.changeCount
        var posted: [CGEvent] = []
        var savedFirst = false
        let insertion = TextInsertion(
            pasteboard: pasteboard, restoreDelay: .zero, pasteTimeout: .zero
        ) { posted = $0 }

        let inserted = try await insertion.replace(";fu", with: Self.expansion) {
            savedFirst = promised.wasRead
            return false
        }

        #expect(inserted == nil)
        #expect(savedFirst)
        #expect(posted.isEmpty)
        #expect(pasteboard.changeCount == before)
        #expect(pasteboard.string(forType: .string) == "old")
    }

    @Test func keepsACopyMadeWhileTheClipboardWasSaved() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("old", forType: .string)
        var posted: [CGEvent] = []
        let insertion = TextInsertion(
            pasteboard: pasteboard, restoreDelay: .zero, pasteTimeout: .zero
        ) { posted = $0 }

        await #expect(throws: TextInsertion.Failure.clipboardChanged) {
            _ = try await insertion.replace(";fu", with: Self.expansion) {
                pasteboard.clearContents()
                pasteboard.setString("copied meanwhile", forType: .string)
                return true
            }
        }

        #expect(posted.isEmpty)
        #expect(pasteboard.string(forType: .string) == "copied meanwhile")
    }

    @Test func undoRemovesTheTextAndTypesTheKeywordAgain() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        var posted: [CGEvent] = []
        let insertion = TextInsertion(
            pasteboard: pasteboard, restoreDelay: .zero, pasteTimeout: .zero
        ) { posted = $0 }
        let short = SnippetTemplate("a{cursor}bc").expand(
            .init(fields: [:], date: "", time: "", clipboard: ""))

        let inserted = try #require(await insertion.replace(";fu", with: short) { true })
        try insertion.undo(inserted)

        let right = Int64(kVK_RightArrow)
        let delete = Int64(kVK_Delete)
        #expect(Self.keys(posted) == [right, right, delete, delete, delete, 0])
        #expect(posted.last.map(Self.text) == ";fu")
        #expect(posted.allSatisfy(Keystrokes.isPosted))
    }

    @Test func typesLongTextInChunksWithoutSplittingCharacters() throws {
        let text = String(repeating: "あ", count: 19) + "👋🏽"

        let events = try Keystrokes.typing(text)

        let downs = events.filter { $0.type == .keyDown }.map(Self.text)
        #expect(downs == [String(repeating: "あ", count: 19), "👋🏽"])
    }
}
