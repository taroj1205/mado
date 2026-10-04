import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite struct SnippetEditorLayoutTests {
    @Test(arguments: ["Bug report template", "Email sign-off"])
    func theNameFieldTakesTheRowBesideTheKeyword(_ name: String) {
        let panel = GlassPanel(
            kind: .panel, contentRect: NSRect(x: 100, y: 100, width: 760, height: 560),
            shape: .rounded(20))
        let editor = SnippetEditor()
        panel.glass.contentView = editor
        editor.show(
            [.init(id: "a", values: .init(name: name, keyword: #"\bug"#, text: "Steps"))],
            selecting: "a")
        editor.layoutSubtreeIfNeeded()

        #expect(!editor.nameField.hasAmbiguousLayout)
        #expect(editor.nameField.frame.width > editor.keywordField.frame.width * 2)
    }

    @Test func marksPlaceholdersOnlyNearTheStartOfAHugeText() {
        let editor = SnippetEditor()
        var scanned: [Int] = []
        editor.tokens = { text in
            scanned.append(text.utf16.count)
            return [NSRange(location: 0, length: 6)]
        }
        let huge = String(repeating: "{date}", count: SnippetEditor.highlightedLength)
        let entry = SnippetEditor.Entry(id: "huge", values: .init(name: "Huge", text: huge))

        editor.show([entry], selecting: "huge")

        let text = editor.textView.attributedString()
        let token = unsafe text.attribute(.backgroundColor, at: 0, effectiveRange: nil)
        #expect(token != nil)
        #expect(!scanned.isEmpty)
        #expect(scanned.allSatisfy { $0 == SnippetEditor.highlightedLength })
    }

    @Test func theNewSnippetButtonSitsAsFarFromTheRightEdgeAsFromTheTop() {
        let panel = GlassPanel(
            kind: .panel, contentRect: NSRect(x: 100, y: 100, width: 760, height: 560),
            shape: .rounded(20))
        let editor = SnippetEditor()
        panel.glass.contentView = editor
        editor.show([], selecting: nil)
        editor.layoutSubtreeIfNeeded()

        let edges = editor.convert(editor.bounds, to: nil)
        let button = editor.newSnippet.convert(editor.newSnippet.bounds, to: nil)

        #expect(abs((edges.maxY - button.maxY) - (edges.maxX - button.maxX)) < 0.5)
    }

    @Test func commandNStartsANewSnippetFromTheText() throws {
        let panel = GlassPanel(
            kind: .panel, contentRect: NSRect(x: 100, y: 100, width: 760, height: 560),
            shape: .rounded(20))
        let editor = SnippetEditor()
        panel.glass.contentView = editor
        editor.show(
            [.init(id: "sig", values: .init(name: "Sign-off", keyword: #"\sig"#, text: "Bye"))],
            selecting: "sig")
        panel.makeFirstResponder(editor.textView)
        let event = try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, characters: "n",
                charactersIgnoringModifiers: "n", isARepeat: false, keyCode: UInt16(kVK_ANSI_N)))

        #expect(panel.performKeyEquivalent(with: event))
        #expect(editor.editing == nil)
        #expect(editor.nameField.stringValue.isEmpty)
        panel.makeFirstResponder(nil)
    }
}
