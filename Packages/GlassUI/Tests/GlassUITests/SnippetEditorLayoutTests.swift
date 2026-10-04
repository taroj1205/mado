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
}
