import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite(.serialized) final class SnippetEditorTests {
    private static let fillIn = #"{fill-in name="Name"}"#
    private static let signOff = SnippetEditor.Entry(
        id: "sig", values: .init(name: "Email sign-off", keyword: #"\sig"#, text: "Bye {cursor}"))
    private static let address = SnippetEditor.Entry(
        id: "addr", values: .init(name: "Home address", keyword: #"\addr"#, text: "1 Queen St"))

    private let panel = GlassPanel(
        kind: .panel, contentRect: NSRect(x: 100, y: 100, width: 760, height: 560),
        shape: .rounded(20))
    private let editor = SnippetEditor()
    private var saved: [(String?, SnippetEditor.Values)] = []
    private var problem: String?

    init() {
        panel.glass.contentView = editor
        editor.fillInToken = Self.fillIn
        editor.onSave = { [weak self] id, values in
            self?.saved.append((id, values))
            return self?.problem
        }
    }

    @Test func listsSnippetsAndLoadsTheSelectedOne() {
        editor.show([Self.signOff, Self.address], selecting: "addr")

        #expect(editor.list.entries == [Self.signOff, Self.address])
        #expect(editor.list.selectedID == "addr")
        #expect(editor.editing == "addr")
        #expect(editor.nameField.stringValue == "Home address")
        #expect(editor.keywordField.stringValue == #"\addr"#)
        #expect(editor.textView.string == "1 Queen St")
        #expect(editor.empty.isHidden)
        #expect(editor.contextPill.text == "Snippets")
    }

    @Test func searchFiltersByNameKeywordOrTextAndArrowsMove() {
        editor.show([Self.signOff, Self.address], selecting: nil)
        editor.begin()

        type("queen", in: editor.search)
        #expect(editor.list.entries == [Self.address])
        #expect(editor.editing == "addr")

        type("", in: editor.search)
        press(kVK_DownArrow, "\u{F701}")
        #expect(editor.editing == "addr")
        press(kVK_UpArrow, "\u{F700}")
        #expect(editor.editing == "sig")

        type("zzz", in: editor.search)
        #expect(editor.list.entries.isEmpty)
        #expect(!editor.empty.isHidden)
        #expect(editor.empty.stringValue == "No matching snippets")
        #expect(editor.editing == nil)
        #expect(editor.nameField.stringValue.isEmpty)
    }

    @Test func searchingKeepsUnsavedEditsWhileTheSnippetStaysSelected() {
        editor.show([Self.signOff, Self.address], selecting: "addr")
        type("Home and away", in: editor.nameField)

        type("queen", in: editor.search)
        let kept = editor.nameField.stringValue
        type("sign", in: editor.search)

        #expect(kept == "Home and away")
        #expect(editor.editing == "sig")
        #expect(editor.nameField.stringValue == "Email sign-off")
    }

    @Test func searchingKeepsANewDraftUntilAnotherSnippetIsChosen() {
        editor.show([Self.signOff, Self.address], selecting: "sig")
        editor.newSnippet.performClick(nil)
        type("Zoom link", in: editor.nameField)

        type("queen", in: editor.search)
        let kept = (editor.nameField.stringValue, editor.editing, editor.list.selectedID)
        press(kVK_DownArrow, "\u{F701}")

        #expect(editor.list.entries == [Self.address])
        #expect(kept.0 == "Zoom link")
        #expect(kept.1 == nil && kept.2 == nil)
        #expect(editor.editing == "addr")
        #expect(editor.nameField.stringValue == "Home address")
    }

    @Test func returnSavesTheTrimmedFormAndShowsAProblem() {
        editor.show([Self.signOff], selecting: "sig")
        editor.nameField.stringValue = "  Sign-off "
        problem = "“\\sig” already expands Bug report."

        panel.makeFirstResponder(editor.keywordField)
        press(kVK_Return, "\r")
        #expect(saved.map(\.0) == ["sig"])
        #expect(saved.first?.1 == .init(name: "Sign-off", keyword: #"\sig"#, text: "Bye {cursor}"))
        #expect(!editor.problemLabel.isHidden)
        #expect(editor.problemLabel.stringValue == problem)

        problem = nil
        #expect(editor.save.accessibilityPerformPress())
        #expect(editor.problemLabel.isHidden)
        #expect(saved.count == 2)
    }

    @Test func aMissingFieldBlocksSavingAndFocusesIt() {
        editor.show([], selecting: nil)
        #expect(editor.empty.stringValue == "No snippets yet")

        #expect(editor.save.accessibilityPerformPress())
        #expect(panel.firstResponder === editor.nameField.currentEditor())
        editor.nameField.stringValue = "Name"
        #expect(editor.save.accessibilityPerformPress())
        #expect(panel.firstResponder === editor.keywordField.currentEditor())
        editor.keywordField.stringValue = ";n"
        #expect(editor.save.accessibilityPerformPress())
        #expect(panel.firstResponder === editor.textView)
        #expect(saved.isEmpty)
    }

    @Test func newSnippetStartsABlankFormSavedAsNew() {
        editor.show([Self.signOff], selecting: "sig")

        editor.newSnippet.performClick(nil)
        #expect(editor.list.selectedID == nil)
        #expect(editor.editing == nil)
        #expect(editor.nameField.stringValue.isEmpty)
        #expect(panel.firstResponder === editor.nameField.currentEditor())

        editor.nameField.stringValue = "Zoom"
        editor.keywordField.stringValue = #"\zoom"#
        editor.textView.string = "https://zoom.us/j/1"
        #expect(editor.save.accessibilityPerformPress())
        #expect(saved.map(\.0) == [nil])
    }

    @Test func chipsInsertPlaceholdersAndSelectTheFieldName() {
        editor.show([], selecting: nil)
        #expect(
            editor.chips.map(\.title) == [
                "{date}", "{time}", "{clipboard}", "{cursor}", "{fill-in}",
            ])

        editor.chips[0].performClick(nil)
        editor.chips[4].performClick(nil)

        #expect(editor.textView.string == "{date}" + Self.fillIn)
        #expect(editor.textView.selectedRange() == NSRange(location: 21, length: 4))
        #expect(panel.firstResponder === editor.textView)
    }

    @Test func marksThePlaceholdersInTheText() {
        editor.tokens = { _ in [NSRange(location: 4, length: 8)] }
        editor.show([Self.signOff], selecting: "sig")

        let text = editor.textView.attributedString()
        let token = unsafe text.attribute(.backgroundColor, at: 5, effectiveRange: nil)
        let plain = unsafe text.attribute(.backgroundColor, at: 1, effectiveRange: nil)
        let font = unsafe text.attribute(.font, at: 5, effectiveRange: nil) as? NSFont

        #expect(token != nil)
        #expect(plain == nil)
        #expect(font?.isFixedPitch == true)
        #expect(!editor.textView.isAutomaticQuoteSubstitutionEnabled)
    }

    @Test func shortcutsPasteSaveDeleteAndClose() {
        var pasted: [SnippetEditor.Values] = []
        var deleted: [String] = []
        var closes = 0
        editor.onPaste = { pasted.append($0) }
        editor.onDelete = { deleted.append($0) }
        editor.onClose = { closes += 1 }
        editor.show([Self.signOff], selecting: "sig")
        panel.makeFirstResponder(editor.textView)

        press(kVK_Return, "\r", .command)
        press(kVK_ANSI_X, "x", .control)
        press(kVK_Escape, "\u{1B}")

        #expect(pasted == [Self.signOff.values])
        #expect(deleted == ["sig"])
        #expect(closes == 1)
        #expect(editor.paste.accessibilityLabel() == "Paste")
    }

    @Test func actionsListDeleteOnlyForASavedSnippet() {
        editor.show([Self.signOff], selecting: "sig")
        panel.makeFirstResponder(editor.textView)

        press(kVK_ANSI_K, "k", .command)
        let forSaved = editor.actionPanel?.rows.map(\.label.stringValue)
        let open = editor.actionPanel?.isVisible
        press(kVK_ANSI_K, "k", .command)
        let refocused = panel.firstResponder === editor.textView
        editor.newSnippet.performClick(nil)
        press(kVK_ANSI_K, "k", .command)
        let fresh = editor.actionPanel?.rows.map(\.label.stringValue)

        #expect(forSaved == ["Paste", "Save", "Delete Snippet"])
        #expect(open == true)
        #expect(refocused)
        #expect(fresh == ["Paste", "Save"])
    }

    @Test func theSwitchShowsWhereExpansionIsOff() {
        var turned: [Bool] = []
        editor.onExpandChange = { turned.append($0) }

        editor.showExpansion(true, offIn: ["Terminal", "1Password"])
        #expect(editor.expandSwitch.state == .on)
        #expect(editor.expandDetail.stringValue == "Off in: Terminal, 1Password")
        editor.expandSwitch.performClick(nil)
        editor.showExpansion(false, offIn: [])

        #expect(turned == [false])
        #expect(editor.expandDetail.isHidden)
    }

    @Test func layoutFollowsTheCanvas() {
        editor.show([Self.signOff], selecting: "sig")
        panel.layoutIfNeeded()
        let buttons = editor.buttons.frame
        let field = { (field: NSTextField) in
            sequence(first: field as NSView) { unsafe $0.superview }.first { $0 is NSBox }
        }

        #expect(editor.list.frame.minX == 8)
        #expect(editor.list.frame.width == 244)
        #expect(SnippetList.rowHeight == 40)
        #expect(buttons.minY == 10)
        #expect(editor.frame.maxX - buttons.maxX == 10)
        #expect(editor.contextPill.frame.minX == 10)
        #expect(field(editor.keywordField)?.frame.width == 150)
        #expect(field(editor.nameField)?.frame.height == 28)
        #expect(editor.keywordField.font?.isFixedPitch == true)
        let ambiguous = editor.subviews.contains(where: \.hasAmbiguousLayout)
        #expect(!ambiguous)
    }

    private func type(_ text: String, in field: NSTextField) {
        panel.makeFirstResponder(field)
        field.stringValue = text
        NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: field)
    }

    private func press(
        _ keyCode: Int, _ characters: String, _ modifiers: NSEvent.ModifierFlags = []
    ) {
        guard
            let event = NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, characters: characters,
                charactersIgnoringModifiers: characters, isARepeat: false,
                keyCode: UInt16(keyCode))
        else {
            Issue.record("Could not make a key event for \(keyCode)")
            return
        }
        let shortcut = !modifiers.isDisjoint(with: [.command, .control])
        if shortcut, panel.performKeyEquivalent(with: event) { return }
        panel.sendEvent(event)
    }

    isolated deinit {
        panel.makeFirstResponder(nil)
    }
}
