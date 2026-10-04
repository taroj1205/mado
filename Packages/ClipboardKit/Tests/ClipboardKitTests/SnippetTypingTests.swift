import AppKit
import Carbon.HIToolbox
import InputKit
import Testing

@testable import ClipboardKit

@MainActor
@Suite struct SnippetTypingTests {
    private static let snippet = Snippet(name: "Follow-up", keyword: ";fu", text: "Hi")
    private static let codes: [Character: Int] = [
        ";": kVK_ANSI_Semicolon, "f": kVK_ANSI_F, "u": kVK_ANSI_U,
    ]

    private static func typing() -> SnippetTyping {
        var typing = SnippetTyping()
        var settings = SnippetSettings()
        settings.save(snippet)
        typing.settings = settings
        return typing
    }

    private static func type(
        _ text: String, into typing: inout SnippetTyping, canExpand: Bool = true
    ) throws -> [String] {
        try text.compactMap { character in
            let event = try TestKeys.event(codes[character] ?? 0, String(character), [])
            guard case .expand(let snippet) = typing.handle(.keyDown, event, canExpand: canExpand)
            else { return nil }
            return snippet.keyword
        }
    }

    private static func inserted(_ typed: String = ";fu") async throws -> TextInsertion.Inserted {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let insertion = TextInsertion(
            pasteboard: pasteboard, restoreDelay: .zero, pasteTimeout: .zero
        ) { events in
            #expect(!events.isEmpty)
        }
        let expansion = SnippetTemplate("Hi").expand(
            .init(fields: [:], date: "", time: "", clipboard: ""))
        return try #require(await insertion.replace(typed, with: expansion) { true })
    }

    private static func commandZ() throws -> CGEvent {
        let undoKey = Int(KeyboardLayout.commandKeyCode(typing: "z") ?? CGKeyCode(kVK_ANSI_Z))
        return try TestKeys.event(undoKey, "z", .maskCommand)
    }

    @Test func expandsAKeywordTypedElsewhere() throws {
        var typing = Self.typing()

        #expect(try Self.type("a;fu", into: &typing) == [";fu"])
    }

    @Test func staysQuietWhereItCannotExpandOrIsSwitchedOff() throws {
        var typing = Self.typing()

        let blocked = try Self.type(";fu", into: &typing, canExpand: false)
        let split = try Self.type(";f", into: &typing, canExpand: true)
        _ = try Self.type("x", into: &typing, canExpand: false)
        let resumed = try Self.type("u", into: &typing)
        typing.settings.expands = false
        let off = try Self.type(";fu", into: &typing)

        #expect(blocked.isEmpty)
        #expect(split.isEmpty)
        #expect(resumed.isEmpty)
        #expect(off.isEmpty)
    }

    @Test func forgetsTheKeywordOnAClickOrItsOwnKeys() throws {
        var typing = Self.typing()
        let click = try #require(
            CGEvent(
                mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: .zero,
                mouseButton: .left))
        let posted = try TestKeys.event(kVK_ANSI_U, "u", [])
        posted.setIntegerValueField(.eventSourceUserData, value: Keystrokes.marker)

        _ = try Self.type(";f", into: &typing)
        _ = typing.handle(.leftMouseDown, click, canExpand: true)
        let afterClick = try Self.type("u", into: &typing)
        _ = try Self.type(";f", into: &typing)
        let fromMado = typing.handle(.keyDown, posted, canExpand: true)

        #expect(afterClick.isEmpty)
        guard case .pass = fromMado else {
            Issue.record("Mado's own keys must not expand")
            return
        }
        #expect(try Self.type("u", into: &typing) == [";fu"])
    }

    @Test func notesInputThatArrivesAfterTheKeywordMatched() throws {
        var typing = Self.typing()
        let click = try #require(
            CGEvent(
                mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: .zero,
                mouseButton: .left))
        let posted = try TestKeys.event(kVK_Delete, "\u{7F}", [])
        posted.setIntegerValueField(.eventSourceUserData, value: Keystrokes.marker)

        _ = try Self.type(";fu", into: &typing)
        let matched = typing.inputAfterMatch
        _ = typing.handle(.keyDown, posted, canExpand: false)
        let afterOwnKeys = typing.inputAfterMatch
        _ = try Self.type("x", into: &typing, canExpand: false)
        let afterTyping = typing.inputAfterMatch
        _ = try Self.type(";fu", into: &typing)
        _ = typing.handle(.leftMouseDown, click, canExpand: false)

        #expect(!matched)
        #expect(!afterOwnKeys)
        #expect(afterTyping)
        #expect(typing.inputAfterMatch)
    }

    @Test func undoesOnlyATypedKeywordWithCommandZRightAfter() async throws {
        var typing = Self.typing()
        typing.expanded(try await Self.inserted())

        let undo = typing.handle(.keyDown, try Self.commandZ(), canExpand: true)
        let again = typing.handle(.keyDown, try Self.commandZ(), canExpand: true)
        typing.expanded(try await Self.inserted())
        _ = try Self.type("x", into: &typing)
        let late = typing.handle(.keyDown, try Self.commandZ(), canExpand: true)
        typing.expanded(try await Self.inserted())
        typing.expanded(try await Self.inserted(""))
        let pasted = typing.handle(.keyDown, try Self.commandZ(), canExpand: true)

        guard case .undo(let inserted) = undo else {
            Issue.record("⌘Z right after should undo")
            return
        }
        #expect(inserted.replaced == ";fu")
        for outcome in [again, late, pasted] {
            guard case .pass = outcome else {
                Issue.record("⌘Z undoes only a typed keyword, once, right after")
                return
            }
        }
    }
}
