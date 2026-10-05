import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct MergePaneTests {
    private let pane = MergePane()

    private func merge(_ texts: [String], joins: Bool = true) -> LauncherView.Merge {
        .init(title: "Merge", texts: texts, joins: joins, note: "note", action: "Paste Merged")
    }

    @Test func itemsJoinWithTheChosenSeparatorAfterTrimmingEachOne() {
        #expect(MergePane.join([" a\n", "\nb  ", "", "c"], with: "\n") == "a\nb\nc")
        #expect(MergePane.join(["a", "b"], with: ", ") == "a, b")
        #expect(MergePane.join([], with: "\n").isEmpty)
    }

    @Test func strippingTrimsLinesAndDropsBlankOnes() {
        #expect(MergePane.stripped("  a  \n\n\t b\n   \nc") == "a\nb\nc")
    }

    @Test func showingAMergeFillsTheEditorAndRevealsThePane() {
        pane.show(merge(["one", "two"]), focusing: false)
        #expect(!pane.isHidden)
        #expect(pane.text == "one\ntwo")
        #expect(pane.title.stringValue == "Merge")
        #expect(pane.note.stringValue == "note")
        #expect(!pane.joinRow.isHidden)
        pane.show(nil, focusing: false)
        #expect(pane.isHidden)
        #expect(pane.merge == nil)
    }

    @Test func aSingleItemIsEditedAsIsWithoutTheJoinMenu() {
        pane.show(merge(["  keep\nthis  \n"], joins: false), focusing: false)
        #expect(pane.text == "  keep\nthis  \n")
        #expect(pane.joinRow.isHidden)
    }

    @Test func changingTheSeparatorRebuildsTheText() {
        pane.show(merge(["a", "b"]), focusing: false)
        pane.joinMenu.selectItem(at: 2)
        pane.joinMenu.sendAction(pane.joinMenu.action, to: pane.joinMenu.target)
        #expect(pane.text == "a b")
        #expect(MergePane.separators.map(\.title) == ["New line", "Blank line", "Space", "Comma"])
    }

    @Test func showingTheSameMergeAgainKeepsTheEditsButANewOneStartsOver() {
        pane.show(merge(["a", "b"]), focusing: false)
        pane.editor.string = "edited"
        pane.show(merge(["a", "b"]), focusing: false)
        #expect(pane.text == "edited")
        pane.show(merge(["a", "b", "c"]), focusing: false)
        #expect(pane.text == "a\nb\nc")
    }

    @Test func stripFormattingEditsTheTextAndCanBeUndone() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300), styleMask: [.titled],
            backing: .buffered, defer: false)
        window.contentView = pane
        pane.show(merge(["  a  \n\n b"], joins: false), focusing: true)
        pane.strip.performClick(nil)
        #expect(pane.text == "a\nb")
        #expect(pane.editor.undoManager?.canUndo == true)
    }

    @Test func savingASnippetHandsOverTheEditedText() {
        var saved: [String] = []
        pane.onSnippet = { saved.append($0) }
        pane.show(merge(["a", "b"]), focusing: false)
        pane.editor.string = "edited"
        pane.snippet.performClick(nil)
        #expect(saved == ["edited"])
    }

    @Test func escapeInTheEditorLeavesEditing() {
        var escapes = 0
        pane.onEscape = { escapes += 1 }
        pane.show(merge(["a"]), focusing: false)
        #expect(pane.textView(pane.editor, doCommandBy: #selector(NSResponder.cancelOperation)))
        #expect(!pane.textView(pane.editor, doCommandBy: #selector(NSResponder.moveDown)))
        #expect(escapes == 1)
    }

    @Test func theBoxGrowsWithTheTextWithinItsLimits() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400), styleMask: [.titled],
            backing: .buffered, defer: false)
        window.contentView = pane
        pane.frame = NSRect(x: 0, y: 0, width: 480, height: 400)
        pane.show(merge(["a"], joins: false), focusing: false)
        pane.layoutSubtreeIfNeeded()
        let short = pane.box.frame.height
        pane.show(
            merge([Array(repeating: "line", count: 60).joined(separator: "\n")], joins: false),
            focusing: false)
        pane.layoutSubtreeIfNeeded()
        let long = pane.box.frame.height
        #expect(short < long)
        #expect(long <= 220)
    }
}
