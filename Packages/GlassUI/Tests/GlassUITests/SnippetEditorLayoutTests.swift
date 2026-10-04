import AppKit
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
}
