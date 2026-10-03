import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite(.serialized) final class FillInFormTests {
    private static let fields = [
        FillInForm.Field(name: "Name", options: []),
        FillInForm.Field(name: "Day", options: ["Monday", "Thursday"]),
        FillInForm.Field(name: "Topic", options: []),
    ]

    private let panel = GlassPanel(
        kind: .panel, contentRect: NSRect(x: 100, y: 100, width: 420, height: 300),
        shape: .rounded(22))
    private let form = FillInForm()

    init() {
        panel.glass.contentView = form
        form.preview = { values in
            let name = values["Name"] ?? ""
            let text = "Hi \(name), by \(values["Day"] ?? "")."
            return FillInForm.Preview(
                text: text, values: [NSRange(location: 3, length: name.utf16.count)])
        }
    }

    @Test func showsTheSnippetAndOneRowPerFieldInOrder() throws {
        form.show(name: "Meeting follow-up", keyword: ";fu", fields: Self.fields)
        form.focus()

        let popUp = try #require(form.controls[1].control as? NSPopUpButton)
        #expect(form.title.stringValue == "Meeting follow-up")
        #expect(form.subtitle.stringValue == "Snippet · keyword ;fu")
        #expect(form.controls.map(\.name) == ["Name", "Day", "Topic"])
        #expect(form.controls[0].control is NSTextField)
        #expect(popUp.itemTitles == ["Monday", "Thursday"])
        #expect(form.values == ["Name": "", "Day": "Monday", "Topic": ""])
        #expect(
            panel.firstResponder === (form.controls[0].control as? NSTextField)?.currentEditor())
        #expect(form.controls[0].control.accessibilityLabel() == "Name")
    }

    @Test func tabMovesBetweenFieldsInOrder() {
        form.show(name: "Meeting follow-up", keyword: ";fu", fields: Self.fields)

        let loop = form.controls.map(\.control)
        #expect(unsafe loop[0].nextKeyView === loop[1])
        #expect(unsafe loop[1].nextKeyView === loop[2])
        #expect(unsafe loop[2].nextKeyView === loop[0])
    }

    @Test func thePreviewFollowsTheFieldsWithValuesInBold() throws {
        form.show(name: "Meeting follow-up", keyword: ";fu", fields: Self.fields)
        let name = try #require(form.controls[0].control as? NSTextField)
        let day = try #require(form.controls[1].control as? NSPopUpButton)

        name.stringValue = "Hana"
        NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: name)
        day.selectItem(at: 1)
        _ = day.sendAction(day.action, to: day.target)

        let preview = form.previewText.attributedStringValue
        let bold = unsafe preview.attribute(.font, at: 4, effectiveRange: nil) as? NSFont
        let plain = unsafe preview.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        #expect(preview.string == "Hi Hana, by Thursday.")
        #expect(bold?.fontDescriptor.symbolicTraits.contains(.bold) == true)
        #expect(plain?.fontDescriptor.symbolicTraits.contains(.bold) == false)
    }

    @Test func returnInsertsAndEscapeCancels() throws {
        var inserted: [[String: String]] = []
        var cancels = 0
        form.onInsert = { inserted.append($0) }
        form.onCancel = { cancels += 1 }
        form.show(name: "Meeting follow-up", keyword: ";fu", fields: Self.fields)
        form.focus()
        let name = try #require(form.controls[0].control as? NSTextField)
        name.stringValue = "Hana"

        press(kVK_Return, "\r")
        press(kVK_Escape, "\u{1B}")
        panel.makeFirstResponder(form.controls[1].control)
        press(kVK_Return, "\r")
        form.insert.performClick(nil)
        form.cancel.performClick(nil)

        #expect(inserted.count == 3)
        #expect(inserted.first == ["Name": "Hana", "Day": "Monday", "Topic": ""])
        #expect(cancels == 2)
    }

    @Test func thePanelGrowsWithThePreviewAndKeepsItsTop() throws {
        form.show(name: "Meeting follow-up", keyword: ";fu", fields: Self.fields)
        panel.setFrame(
            NSRect(origin: NSPoint(x: 100, y: 500), size: form.fittingSize), display: false)
        let before = panel.frame
        let name = try #require(form.controls[0].control as? NSTextField)

        name.stringValue = String(repeating: "Hana ", count: 40)
        NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: name)

        #expect(panel.frame.height > before.height)
        #expect(panel.frame.maxY == before.maxY)
        #expect(panel.frame.width == 420)
    }

    @Test(.enabled(if: !NSScreen.screens.isEmpty, "Keeping the panel on screen needs a screen"))
    func thePanelGrowingAtTheBottomOfTheScreenStaysOnIt() throws {
        let visible = try #require(NSScreen.screens.first).visibleFrame
        form.show(name: "Meeting follow-up", keyword: ";fu", fields: Self.fields)
        panel.setFrame(
            NSRect(origin: NSPoint(x: visible.minX + 40, y: visible.minY), size: form.fittingSize),
            display: false)
        let before = panel.frame
        let name = try #require(form.controls[0].control as? NSTextField)

        name.stringValue = String(repeating: "Hana ", count: 40)
        NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: name)

        #expect(panel.frame.height > before.height)
        #expect(panel.frame.minY == visible.minY)
    }

    @Test func thePreviewShowsOnlyTheStartOfAHugeExpansion() {
        let huge = String(repeating: "x", count: 1_000_000)
        form.preview = { _ in
            FillInForm.Preview(
                text: "Hi " + huge,
                values: [NSRange(location: 0, length: 2), NSRange(location: 500_000, length: 3)])
        }

        form.show(name: "Clipboard", keyword: ";cb", fields: Self.fields)

        let shown = form.previewText.attributedStringValue
        let bold = unsafe shown.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        #expect(shown.length == 2_000)
        #expect(bold?.fontDescriptor.symbolicTraits.contains(.bold) == true)
        #expect(form.previewText.accessibilityLabel()?.count == "Preview: ".count + 2_000)
    }

    @Test func layoutFollowsTheCanvas() {
        form.show(name: "Meeting follow-up", keyword: ";fu", fields: Self.fields)
        let size = form.fittingSize
        panel.setContentSize(size)
        panel.layoutIfNeeded()

        #expect(size.width == 420)
        #expect(form.insert.frame.height == 26)
        #expect(form.controls[1].control.frame.width == 160)
        let ambiguous = form.subviews.contains(where: \.hasAmbiguousLayout)
        #expect(!ambiguous)
    }

    @Test func manyFieldsScrollInsideTheScreenAndFollowTheFocus() throws {
        let many = (1...40).map { FillInForm.Field(name: "Field \($0)", options: []) }
        form.show(name: "Long form", keyword: ";long", fields: many)
        form.maxHeight = 600
        let size = form.fittingSize
        panel.setContentSize(size)
        panel.layoutIfNeeded()
        let scroll = try #require(form.rows.enclosingScrollView)
        let last = try #require(form.controls.last?.control)

        let lastFrame = last.convert(last.bounds, to: form.rows)
        let lastShownAtFirst = scroll.documentVisibleRect.contains(lastFrame)
        panel.makeFirstResponder(last)
        let lastShownWhenFocused = scroll.documentVisibleRect.contains(lastFrame)

        #expect(size.height == 600)
        #expect(form.bounds.contains(form.insert.convert(form.insert.bounds, to: form)))
        #expect(!lastShownAtFirst)
        #expect(lastShownWhenFocused)
    }

    @Test func aShortFormKeepsItsNaturalHeightUnderTheLimit() {
        form.show(name: "Meeting follow-up", keyword: ";fu", fields: Self.fields)
        let natural = form.fittingSize
        form.maxHeight = 600

        #expect(form.fittingSize == natural)
        #expect(natural.height < 600)
    }

    private func press(_ keyCode: Int, _ characters: String) {
        guard
            let event = NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, characters: characters,
                charactersIgnoringModifiers: characters, isARepeat: false,
                keyCode: UInt16(keyCode))
        else {
            Issue.record("Could not make a key event for \(keyCode)")
            return
        }
        panel.sendEvent(event)
    }

    isolated deinit {
        panel.makeFirstResponder(nil)
    }
}
